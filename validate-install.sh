#!/bin/ksh
# ============================================================================
# OpenBSD KDE Desktop Suite - Installation validation (read-only)
# ============================================================================
# Script:  validate-install.sh
# Version: 2.1.0
# Purpose: verify an installed Plasma desktop without changing anything
# Usage:   ksh validate-install.sh [--verbose] [--json]
# License: MIT License - https://github.com/azazelpy/openbsd
# ============================================================================
#
# Runs as a normal user. Exit status: 0 = no failures, 1 = at least one FAIL.
# Warnings never fail the run: they describe optional or cosmetic gaps.
# ============================================================================

set -u
set -o pipefail 2>/dev/null || true

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

JSON=0

usage() {
	cat <<'USAGE'
validate-install.sh - verify an OpenBSD KDE Plasma installation (read-only)

Usage: ksh validate-install.sh [options]

Options:
  -v, --verbose   also print passing detail for optional components
      --json      print a machine-readable summary as the last line
  -h, --help      this help
USAGE
}

while [ $# -gt 0 ]; do
	case "$1" in
	-v | --verbose)
		VERBOSE=1
		shift
		;;
	--json)
		JSON=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*) die "unknown option: $1 (try --help)" ;;
	esac
done

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------
check_release() {
	case "$(uname -r)" in
	7.8 | 7.9 | 8.*) check_ok "OpenBSD $(uname -r) is a supported release" ;;
	*) check_warn "OpenBSD $(uname -r) is untested (suite targets 7.8+)" ;;
	esac
}

check_x11() {
	if [ -d /usr/X11R6 ] && [ -x /usr/X11R6/bin/X ]; then
		check_ok "X11 file sets installed"
	else
		check_fail "X11 file sets missing (xbase/xshare/xfont/xserv)"
	fi
}

check_plasma() {
	if pkg_installed 'kde-plasma-*'; then
		check_ok "kde-plasma installed: $(pkg_info -e 'kde-plasma-*' | head -1 | awk '{print $1}')"
	else
		check_fail "kde-plasma not installed - run: doas pkg_add kde-plasma"
	fi

	if [ -x /usr/local/bin/startplasma-x11 ]; then
		check_ok "session binary: /usr/local/bin/startplasma-x11"
	else
		check_fail "startplasma-x11 missing (package plasma-workspace)"
	fi

	for _b in plasmashell kwin_x11 konsole; do
		if [ -x "/usr/local/bin/$_b" ]; then
			dbg "present: $_b"
		else
			check_warn "optional binary missing: $_b"
		fi
	done
	check_ok "Plasma core binaries checked"
}

check_dbus_stack() {
	# Only D-Bus is an rc.d service. polkit and consolekit2 have no rc.d
	# script on OpenBSD: D-Bus starts them on demand.
	if pkg_installed 'dbus-*'; then
		check_ok "dbus package installed"
	else
		check_fail "dbus package missing - run: doas pkg_add dbus"
	fi

	if svc_enabled messagebus; then
		check_ok "messagebus enabled in rc.conf.local"
	else
		check_fail "messagebus not enabled - run: doas rcctl enable messagebus"
	fi

	if svc_running messagebus; then
		dbg "messagebus is running"
	elif [ -n "${DISPLAY:-}" ]; then
		check_warn "messagebus is not running (it will start at boot)"
	else
		dbg "no DISPLAY: not judging the runtime state"
	fi

	for _p in polkit consolekit2; do
		if pkg_installed "$_p-*"; then
			check_ok "$_p installed (D-Bus activated, no rc.d service needed)"
		else
			check_warn "$_p missing (authorization/session tracking reduced)"
		fi
	done
}

check_display_manager() {
	if svc_enabled xenodm; then
		check_ok "xenodm enabled in rc.conf.local"
	else
		check_fail "xenodm not enabled - run: doas rcctl enable xenodm"
	fi

	if svc_running xenodm; then
		check_ok "xenodm is running"
	else
		dbg "xenodm not running (starts on boot once enabled)"
	fi
}

check_doas() {
	if [ ! -r /etc/doas.conf ]; then
		check_warn "/etc/doas.conf not readable by $(id -un)"
		return 0
	fi
	if ! grep -qE '^[[:space:]]*permit' /etc/doas.conf; then
		check_fail "/etc/doas.conf has no permit rule"
		return 0
	fi
	if grep -qE '^[[:space:]]*permit[[:space:]].*[[:space:]]:wheel([[:space:]]|$)' /etc/doas.conf; then
		check_ok "doas permits :wheel"
	else
		check_warn "doas has no :wheel rule (fine if you use another rule)"
	fi
	if doas -C /etc/doas.conf >/dev/null 2>&1; then
		check_ok "doas.conf parses (doas -C)"
	elif [ "$(id -u)" -ne 0 ]; then
		dbg "doas -C needs root; skipped"
	else
		check_fail "doas.conf does not parse"
	fi
}

check_user_session() {
	_s=$HOME/.xsession

	if [ ! -f "$_s" ]; then
		check_fail "~/.xsession missing - run: ksh setup-user.sh"
		return 0
	fi

	if [ ! -x "$_s" ]; then
		check_fail "~/.xsession is not executable - chmod 700 ~/.xsession"
	fi

	# Follow the exec line to a real binary, instead of grepping for a name
	# that Plasma 6 no longer ships.
	_bin=$(sed -n 's/.*exec[[:space:]]*//p' "$_s" | awk '{print $NF}' | grep '^/' | head -1)
	if [ -n "$_bin" ] && [ -x "$_bin" ]; then
		check_ok "~/.xsession execs an existing binary: $_bin"
	elif [ -n "$_bin" ]; then
		check_fail "~/.xsession execs $_bin, which does not exist"
	elif grep -q 'startplasma-x11' "$_s"; then
		check_ok "~/.xsession references startplasma-x11"
	else
		check_fail "~/.xsession neither execs a binary nor mentions startplasma-x11"
	fi

	if [ -f "$HOME/.xinitrc" ]; then
		dbg "~/.xinitrc present (startx path)"
	else
		check_warn "~/.xinitrc missing (only 'startx' is affected)"
	fi

	if grep -q '^export ENV=.*\.kshrc' "$HOME/.profile" 2>/dev/null; then
		check_ok "~/.profile exports ENV, so ~/.kshrc is read"
	else
		check_warn "~/.profile does not export ENV: ~/.kshrc is not read by ksh"
	fi

	if [ -f "$HOME/.config/kdeglobals" ]; then
		dbg "~/.config/kdeglobals present"
	else
		check_warn "~/.config/kdeglobals missing (created on first login)"
	fi
}

check_disk() {
	# Packages live in /usr/local, so measure the filesystem holding /usr.
	_mount=/usr
	[ -d /usr ] || _mount=/
	_kb=$(df -k "$_mount" 2>/dev/null | awk 'NR==2 {print $4}')
	[ -n "${_kb:-}" ] || {
		check_warn "cannot read free space on $_mount"
		return 0
	}
	_mb=$((_kb / 1024))
	if [ "$_mb" -ge 2048 ]; then
		check_ok "free space on $_mount: ${_mb} MB"
	elif [ "$_mb" -ge 512 ]; then
		check_warn "free space on $_mount: ${_mb} MB (2 GB recommended)"
	else
		check_fail "free space on $_mount: ${_mb} MB (KDE needs ~2 GB)"
	fi
}

check_backups() {
	if [ "$(id -u)" -eq 0 ]; then
		set -- /root/openbsd-kde-backup-*
		if [ -d "${1:-/nonexistent}" ]; then
			check_ok "configuration backup present: $1"
		else
			check_warn "no /root/openbsd-kde-backup-* found"
		fi
	else
		dbg "root-owned backup directory is not readable as $(id -un)"
	fi
}

check_vmware() {
	is_vmware || return 0
	if pkg_installed 'vmwh-*'; then
		check_ok "VMware guest detected, vmwh installed"
	else
		check_warn "VMware guest detected, vmwh missing (doas ksh setup-vmware.sh)"
	fi
}

# ---------------------------------------------------------------------------
main() {
	hdr "OpenBSD KDE Desktop - installation validation"
	info "host: $(hostname)   user: $(id -un)   date: $(date)"

	check_release
	check_x11
	check_plasma
	check_dbus_stack
	check_display_manager
	check_doas
	check_user_session
	check_disk
	check_backups
	check_vmware

	if summary "validation"; then
		printf '\n'
		ok "installation validated"
		[ "$JSON" = 1 ] && printf '{"passed":%d,"warnings":%d,"failed":0}\n' \
			"$CHECKS_PASS" "$CHECKS_WARN"
		exit 0
	fi

	printf '\n'
	err "installation has failures - see [fail] lines above"
	[ "$JSON" = 1 ] && printf '{"passed":%d,"warnings":%d,"failed":%d}\n' \
		"$CHECKS_PASS" "$CHECKS_WARN" "$CHECKS_FAIL"
	exit 1
}

main
