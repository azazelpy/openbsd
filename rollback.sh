#!/bin/ksh
# ============================================================================
# OpenBSD KDE Desktop Suite - Configuration rollback (run as root)
# ============================================================================
# Script:  rollback.sh
# Version: 2.1.0
# Purpose: restore the configuration files saved by setup-root.sh
# Usage:   doas ksh rollback.sh [--list | --dir DIR] [--yes]
# License: MIT License - https://github.com/azazelpy/openbsd
# ============================================================================
#
# 2.0.0 used [[ =~ ]], which OpenBSD ksh does not implement: the script died
# with a syntax error before it could restore anything. It also claimed to
# restore /etc/rc.conf.local, which setup-root.sh never backed up.
# Both are fixed here: restore is driven by the backup's MANIFEST.tsv.
# ============================================================================

set -eu
set -o pipefail 2>/dev/null || true

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

SCRIPT_NAME="rollback.sh"
BACKUP_DIR=""
LIST_ONLY=0
# Fallback map for backups created by 2.0.0 (no MANIFEST.tsv)
LEGACY_FILES="doas.conf:/etc/doas.conf sysctl.conf:/etc/sysctl.conf Xsetup_0:/etc/X11/xenodm/Xsetup_0"

usage() {
	cat <<'USAGE'
rollback.sh - restore configuration saved by setup-root.sh

Usage: doas ksh rollback.sh [options]

Options:
      --list        show available backups and exit
      --dir DIR     use a specific backup directory (default: newest)
  -n, --dry-run     print what would be restored, change nothing
  -y, --yes         do not ask for confirmation
  -h, --help        this help

What is restored, driven by <backup>/MANIFEST.tsv:
  FILE     every file the installer modified (doas.conf, sysctl.conf,
           installurl, rc.conf.local, wsconsctl.conf), checksum verified
  ABSENT   files the installer created are removed again (installurl,
           wsconsctl.conf, rc.conf.local) when they did not exist before
  SERVICE  messagebus/xenodm go back to the enabled/disabled state they had

Installed packages are NOT removed - the script prints the pkg_delete
command instead, because removing KDE is a separate decision.
USAGE
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
		--list)
			LIST_ONLY=1
			shift
			;;
		--dir)
			[ $# -ge 2 ] || die "$1 needs an argument"
			BACKUP_DIR=$2
			shift 2
			;;
		-n | --dry-run)
			DRY_RUN=1
			shift
			;;
		-y | --yes)
			ASSUME_YES=1
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*) die "unknown option: $1 (try --help)" ;;
		esac
	done
}

list_backups() {
	hdr "Available backups (/root/openbsd-kde-backup-*)"
	_found=0
	for _d in /root/openbsd-kde-backup-*; do
		[ -d "$_d" ] || continue
		_found=$((_found + 1))
		if [ -f "$_d/MANIFEST.tsv" ]; then
			printf '  %s  (%s files, manifest)\n' "$_d" \
				"$(grep -c . "$_d/MANIFEST.tsv" 2>/dev/null || echo 0)"
		else
			printf '  %s  (legacy layout, no manifest)\n' "$_d"
		fi
	done
	[ "$_found" -gt 0 ] || warn "no backups found"
	return 0
}

latest_backup() {
	# Directory names embed YYYYmmdd-HHMMSS, so a name sort is a time sort.
	for _d in /root/openbsd-kde-backup-*; do
		[ -d "$_d" ] && printf '%s\n' "$_d"
	done | sort | tail -1
}

restore_one() {
	_b=$1
	_o=$2
	_want=${3:-}

	if [ ! -f "$_b" ]; then
		check_fail "backup file missing: $_b"
		return 0
	fi

	# Keep the current file before overwriting it, so a rollback is reversible.
	if [ -f "$_o" ] && [ "$DRY_RUN" = 0 ]; then
		cp -p "$_o" "$_o.pre-rollback.$RUNSTAMP" || true
	fi

	if run cp -p "$_b" "$_o"; then
		if [ -n "$_want" ] && [ "$_want" != "unavailable" ]; then
			_got=$(_sha "$_o")
			if [ "$_got" = "$_want" ]; then
				check_ok "restored $_o (checksum verified)"
			else
				check_warn "restored $_o but checksum differs"
			fi
		else
			check_ok "restored $_o"
		fi
	else
		check_fail "could not restore $_o"
	fi
	return 0
}

restore_service() {
	_svc=$1
	_want_state=$2

	if [ "$_want_state" = on ]; then
		if svc_enabled "$_svc"; then
			dbg "$_svc was already enabled"
			return 0
		fi
		if run rcctl enable "$_svc"; then
			check_ok "$_svc enabled again (as before the install)"
		else
			check_fail "could not enable $_svc"
		fi
		return 0
	fi

	# It was off before the installation: turn it back off.
	if svc_enabled "$_svc"; then
		if run rcctl disable "$_svc"; then
			check_ok "$_svc disabled (it was off before the install)"
		else
			check_fail "could not disable $_svc"
		fi
	else
		dbg "$_svc already disabled"
	fi
	return 0
}

remove_absent() {
	_o=$1
	[ -e "$_o" ] || {
		dbg "already absent: $_o"
		return 0
	}
	if run rm -f "$_o"; then
		check_ok "removed $_o (it did not exist before the install)"
	else
		check_fail "could not remove $_o"
	fi
	return 0
}

restore_all() {
	_dir=$1
	tab=$(printf '	')

	if [ -f "$_dir/MANIFEST.tsv" ]; then
		step "Restoring from manifest: $_dir/MANIFEST.tsv"
		while IFS="$tab" read -r _type _src _dst _want; do
			[ -n "${_type:-}" ] || continue
			case "$_type" in
			FILE) restore_one "$_src" "$_dst" "${_want:-}" ;;
			ABSENT) remove_absent "$_dst" ;;
			SERVICE) restore_service "$_dst" "${_want:-off}" ;;
			# 2.1.0 before this change wrote three untyped columns.
			*) restore_one "$_type" "$_src" "${_dst:-}" ;;
			esac
		done <"$_dir/MANIFEST.tsv"
		return 0
	fi

	step "No manifest: using the 2.0.0 layout in $_dir"
	for _pair in $LEGACY_FILES; do
		_name=${_pair%%:*}
		_target=${_pair#*:}
		[ -f "$_dir/$_name" ] || continue
		restore_one "$_dir/$_name" "$_target"
	done
	return 0
}

restart_services() {
	step "Services"
	if svc_running messagebus; then
		run rcctl restart messagebus && ok "messagebus restarted"
	else
		info "messagebus is not running: nothing to restart"
	fi
	if svc_running xenodm; then
		warn "xenodm is running: it will pick up the restored Xsetup_0 on next boot"
	fi
	return 0
}

print_uninstall_hint() {
	hdr "Restored configuration, packages left in place"
	info "to remove the desktop as well (your call, then reboot):"
	printf '  doas pkg_delete kde-plasma dbus polkit consolekit2\n'
	info "your previous configs are kept as <file>.orig.<timestamp>"
	return 0
}

main() {
	parse_args "$@"

	hdr "OpenBSD KDE Desktop Suite v$SUITE_VERSION - rollback"
	[ "$DRY_RUN" = 1 ] && warn "DRY RUN: nothing will be modified"

	if [ "$(id -u)" -ne 0 ] && [ "$LIST_ONLY" = 0 ]; then
		die "run as root: doas ksh $SCRIPT_NAME"
	fi

	if [ "$LIST_ONLY" = 1 ]; then
		list_backups
		exit 0
	fi

	if [ -z "$BACKUP_DIR" ]; then
		_backup_base=$(latest_backup)
		[ -n "$_backup_base" ] || {
			warn "no backups found"
			list_backups
			exit 1
		}
		BACKUP_DIR=$_backup_base
	fi

	[ -d "$BACKUP_DIR" ] || die "backup directory not found: $BACKUP_DIR"
	BACKUP_MANIFEST=""
	info "backup: $BACKUP_DIR"

	if ! ask_yes "restore the files listed above?"; then
		info "cancelled"
		exit 0
	fi

	restore_all "$BACKUP_DIR"
	restart_services

	if summary "rollback"; then
		print_uninstall_hint
		exit 0
	fi
	exit 1
}

main "$@"
