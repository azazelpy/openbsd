#!/bin/ksh
# ============================================================================
# OpenBSD KDE Desktop Suite - lib/common.sh
# ============================================================================
# Shared helpers. Source it, never execute it.
#
#   . "$(dirname "$0")/lib/common.sh"
#
# Targets OpenBSD ksh (pdksh) and mksh. Deliberately free of bashisms:
# no [[ =~ ]], no read -p, no arrays, no echo -e.
# ============================================================================
# License: MIT License - https://github.com/azazelpy/openbsd
# ============================================================================

[ -n "${SUITE_COMMON_LOADED:-}" ] && return 0
SUITE_COMMON_LOADED=1

SUITE_VERSION="2.1.0"

# ---------------------------------------------------------------------------
# Runtime flags (env defaults, overridden by CLI parsing in each script)
# ---------------------------------------------------------------------------
DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}
VERBOSE=${VERBOSE:-0}
LOG_FILE=${LOG_FILE:-}
RUNSTAMP=${RUNSTAMP:-$(date +%Y%m%d-%H%M%S)}
BACKUP_MANIFEST=${BACKUP_MANIFEST:-}

CHECKS_PASS=0
CHECKS_FAIL=0
CHECKS_WARN=0

# ---------------------------------------------------------------------------
# Colour - only on a tty, and honour NO_COLOR
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
	RED=$(printf '\033[0;31m')
	GREEN=$(printf '\033[0;32m')
	YELLOW=$(printf '\033[1;33m')
	BLUE=$(printf '\033[0;34m')
	MAGENTA=$(printf '\033[0;35m')
	CYAN=$(printf '\033[0;36m')
	BOLD=$(printf '\033[1m')
	NC=$(printf '\033[0m')
else
	RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' NC=''
fi

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
_log() {
	_level=$1
	_colour=$2
	shift 2
	if [ -n "$LOG_FILE" ]; then
		printf '%s %-7s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$_level" "$*" \
			>>"$LOG_FILE" 2>/dev/null || true
	fi
	printf '%s%s%s\n' "$_colour" "$*" "$NC"
	return 0
}

hdr() {
	printf '\n%s%s%s\n' "$BOLD$CYAN" "$*" "$NC"
	return 0
}

step() { _log STEP "$BLUE" "==> $*"; }
ok() { _log OK "$GREEN" "  [ok]   $*"; }
warn() { _log WARN "$YELLOW" "  [warn] $*"; }
err() { _log ERROR "$RED" "  [fail] $*"; }
info() { _log INFO "$MAGENTA" "  $*"; }
dbg() {
	[ "$VERBOSE" = 1 ] && _log DEBUG "$CYAN" "  $*"
	return 0
}

die() {
	err "$*"
	printf '\n'
	if [ -n "$LOG_FILE" ]; then
		warn "Aborted. Full log: $LOG_FILE"
	else
		warn "Aborted."
	fi
	exit 1
}

# ---------------------------------------------------------------------------
# Assertions and checks
# ---------------------------------------------------------------------------
check_ok() {
	ok "$*"
	CHECKS_PASS=$((CHECKS_PASS + 1))
	return 0
}

check_warn() {
	warn "$*"
	CHECKS_WARN=$((CHECKS_WARN + 1))
	return 0
}

check_fail() {
	err "$*"
	CHECKS_FAIL=$((CHECKS_FAIL + 1))
	return 0
}

# Prints a summary table; returns 1 when any check failed.
summary() {
	_what=${1:-Checks}
	printf '\n'
	hdr "Summary - $_what"
	printf '  passed %d   warnings %d   failed %d\n' \
		"$CHECKS_PASS" "$CHECKS_WARN" "$CHECKS_FAIL"
	[ "$CHECKS_FAIL" -eq 0 ] || return 1
	return 0
}

# ---------------------------------------------------------------------------
# Command helpers
# ---------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
	for _c in "$@"; do
		have "$_c" || die "required command not found: $_c"
	done
	return 0
}

# run: execute, or print under --dry-run
run() {
	if [ "$DRY_RUN" = 1 ]; then
		printf '%s[dry-run]%s %s\n' "$YELLOW" "$NC" "$*"
		return 0
	fi
	[ "$VERBOSE" = 1 ] && printf '%s+%s %s\n' "$BLUE" "$NC" "$*"
	"$@"
}

# run_must: same, but abort the script when the command fails
run_must() {
	run "$@" || die "command failed: $*"
	return 0
}

ask_yes() {
	_q=$1
	if [ "$ASSUME_YES" = 1 ]; then
		info "$_q -> yes (--yes)"
		return 0
	fi
	if [ ! -t 0 ]; then
		warn "$_q -> no (stdin is not a tty; use --yes to automate)"
		return 1
	fi
	printf '%s%s%s [y/N] ' "$YELLOW" "$_q" "$NC"
	read -r _a
	case "$_a" in
	[yY] | [yY][eE][sS]) return 0 ;;
	*) return 1 ;;
	esac
}

# ---------------------------------------------------------------------------
# OpenBSD primitives
# ---------------------------------------------------------------------------
pkg_installed() {
	# $1: package stem, with or without version (e.g. kde-plasma, kde-plasma-6.4.5)
	[ -n "${1:-}" ] || return 1
	pkg_info -e "$1" >/dev/null 2>&1 && return 0
	case "$1" in
	*-[0-9]*) : ;;
	*) pkg_info -e "$1-*" >/dev/null 2>&1 && return 0 ;;
	esac
	return 1
}

# A package daemon enabled in rc.conf.local (rcctl check only tests "running")
svc_enabled() { rcctl get "$1" status >/dev/null 2>&1; }
svc_running() { rcctl check "$1" >/dev/null 2>&1; }

# OpenBSD only. Call from the root installer before it touches anything.
require_openbsd() {
	[ "$(uname -s)" = "OpenBSD" ] || die "this script requires OpenBSD (found $(uname -s))"
	return 0
}

is_vmware() {
	dmesg 2>/dev/null | grep -qi vmware && return 0
	[ "$(sysctl -n hw.vendor 2>/dev/null)" = "VMware, Inc." ] && return 0
	sysctl -n hw.vendor 2>/dev/null | grep -qi vmware && return 0
	return 1
}

# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------
_sha() {
	if have sha256; then
		sha256 -q "$1" 2>/dev/null
	elif have shasum; then
		shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
	else
		printf 'unavailable'
	fi
}

# backup_file PATH -> PATH.orig.<first-run-stamp>
# The first backup wins: re-running the installer never overwrites the
# original file with the version it generated itself.
backup_file() {
	_src=$1
	[ -e "$_src" ] || return 0
	set -- "$_src".orig.*
	if [ -e "${1:-/nonexistent}" ]; then
		dbg "original already preserved: $1"
		return 0
	fi
	_dst="$_src.orig.$RUNSTAMP"
	if [ "$DRY_RUN" = 1 ]; then
		printf '%s[dry-run]%s cp -p %s %s\n' "$YELLOW" "$NC" "$_src" "$_dst"
		return 0
	fi
	cp -p "$_src" "$_dst" || return 1
	if [ -n "$BACKUP_MANIFEST" ]; then
		printf '%s\t%s\t%s\n' "$_dst" "$_src" "$(_sha "$_dst")" >>"$BACKUP_MANIFEST"
	fi
	dbg "backup: $_src -> $_dst"
	return 0
}

# write_file PATH < content
#  - atomic replace
#  - no write at all when the content is already identical (stable mtime)
#  - the previous version is preserved as <file>.orig.<stamp> ONLY when it
#    differs, so a user edit is never lost and a re-run leaves no clutter
write_file() {
	_dst=$1
	if [ "$DRY_RUN" = 1 ]; then
		printf '%s[dry-run]%s write %s\n' "$YELLOW" "$NC" "$_dst"
		cat >/dev/null
		return 0
	fi
	mkdir -p "$(dirname "$_dst")" || return 1
	_tmp="$_dst.tmp.$$"
	cat >"$_tmp" || return 1

	if [ -f "$_dst" ] && cmp -s "$_tmp" "$_dst"; then
		rm -f "$_tmp"
		dbg "unchanged: $_dst"
		return 0
	fi

	if [ -f "$_dst" ]; then
		_bak="$_dst.orig.$RUNSTAMP"
		[ -e "$_bak" ] && _bak="$_bak.$$"
		if ! cp -p "$_dst" "$_bak"; then
			rm -f "$_tmp"
			return 1
		fi
		if [ -n "$BACKUP_MANIFEST" ]; then
			printf 'FILE	%s	%s	%s\n' "$_bak" "$_dst" "$(_sha "$_bak")" \
				>>"$BACKUP_MANIFEST"
		fi
		dbg "previous version preserved: $_bak"
	fi

	mv "$_tmp" "$_dst"
	return 0
}

# _has_marker FILE MARKER - true when a non-comment line starts with MARKER
# (grep -F alone also matches "#marker", which would silently skip the write)
_has_marker() {
	[ -f "$1" ] || return 1
	awk -v m="$2" '
		{ line = $0; sub(/^[ 	]+/, "", line) }
		substr(line, 1, length(m)) == m { found = 1; exit }
		END { exit(found ? 0 : 1) }
	' "$1"
}

# append_block FILE MARKER BODY - idempotent: writes BODY only when MARKER is absent
append_block() {
	_f=$1
	_marker=$2
	_body=$3
	if _has_marker "$_f" "$_marker"; then
		dbg "already configured: $_marker ($_f)"
		return 1
	fi
	if [ "$DRY_RUN" = 1 ]; then
		printf '%s[dry-run]%s append "%s" to %s\n' "$YELLOW" "$NC" "$_marker" "$_f"
		return 0
	fi
	mkdir -p "$(dirname "$_f")" || return 1
	printf '%s\n' "$_body" >>"$_f" || return 1
	return 0
}

# Render "yes/no" for a boolean expression without leaking exit status
yn() {
	if "$@" >/dev/null 2>&1; then printf 'yes'; else printf 'no'; fi
}
