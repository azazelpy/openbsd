#!/bin/ksh
# ============================================================================
# OpenBSD KDE Desktop Suite - System configuration (run as root)
# ============================================================================
# Script:  setup-root.sh
# Version: 2.1.1
# Purpose: install KDE Plasma 6 and enable the daemons it needs on OpenBSD 8.0
#          (verified on 8.0 and 7.8; see COMPATIBILITY.md)
# Usage:   doas ksh setup-root.sh [options]
# License: MIT License - https://github.com/azazelpy/openbsd
# ============================================================================
#
# Notes on purpose (verified against the OpenBSD 8.0 and 7.8 package indexes):
#   * kde-plasma is a meta package that pulls plasma-desktop, plasma-workspace,
#     kwin, kscreenlocker, kf6-dolphin and konsole.
#   * D-Bus ships as the "dbus" package; its rc.d daemon is "messagebus".
#   * polkit and consolekit2 have NO rc.d script: D-Bus starts them on demand.
#     There is nothing to "enable" for them.
#   * tmux is in the base system, not a package.
#   * vim: 7.8 ships a -no_x11 flavour; 8.0 dropped that flavour and made the
#     default build console-only (only -gtk3 enables the GUI). Handled by OSVER.
# ============================================================================

set -eu
set -o pipefail 2>/dev/null || true

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

SCRIPT_NAME="setup-root.sh"
MIRROR_DEFAULT="https://cdn.openbsd.org/pub/OpenBSD"
MIRROR_URL=""
BACKUP_ROOT=""
WANT_APPS=1
WANT_TOOLS=1
TOUCHPAD=auto

usage() {
	cat <<'USAGE'
setup-root.sh - OpenBSD KDE Desktop Suite (system configuration)

Usage: doas ksh setup-root.sh [options]

Options:
  -m, --mirror URL   package mirror to write to /etc/installurl
                     (default: keep the current one, else cdn.openbsd.org)
      --no-apps      skip firefox/thunderbird/kate
      --no-tools     skip the optional CLI tool set
      --touchpad     force-enable tap-to-click in /etc/wsconsctl.conf
      --no-touchpad  leave /etc/wsconsctl.conf untouched
  -n, --dry-run      print every action, change nothing
  -y, --yes          assume "yes" for every prompt
  -v, --verbose      show executed commands
      --log FILE     also log to FILE (default: /var/log/openbsd-kde-setup-<stamp>.log)
  -h, --help         this help

What it does:
  1. backs up every file it may touch (doas.conf, sysctl.conf, installurl,
     rc.conf.local, wsconsctl.conf) plus the installed package list
  2. configures the package mirror
  3. updates installed packages, installs kde-plasma + dbus + polkit + consolekit2
  4. adds "permit persist :wheel" to doas.conf only if no wheel rule exists
  5. enables the two daemons that actually exist: messagebus and xenodm
  6. optionally enables tap-to-click for touchpads
  7. verifies the result and exits non-zero on failure

It does NOT write sysctl tunables: OpenBSD has no kern.sbmax or kern.somaxkva,
so the "KDE optimizations" of 2.0.0 were inert (see AUDITORIA.md).
USAGE
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
		-m | --mirror)
			[ $# -ge 2 ] || die "$1 needs an argument"
			MIRROR_URL=$2
			shift 2
			;;
		--no-apps)
			WANT_APPS=0
			shift
			;;
		--no-tools)
			WANT_TOOLS=0
			shift
			;;
		--touchpad)
			TOUCHPAD=yes
			shift
			;;
		--no-touchpad)
			TOUCHPAD=no
			shift
			;;
		-n | --dry-run)
			DRY_RUN=1
			shift
			;;
		-y | --yes)
			ASSUME_YES=1
			shift
			;;
		-v | --verbose)
			VERBOSE=1
			shift
			;;
		--log)
			[ $# -ge 2 ] || die "$1 needs an argument"
			LOG_FILE=$2
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			die "unknown option: $1 (try --help)"
			;;
		esac
	done
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
preflight() {
	step "Pre-flight checks"

	[ "$(id -u)" -eq 0 ] || die "run as root: doas ksh $SCRIPT_NAME"
	check_ok "running as root"

	require_openbsd
	check_ok "operating system: $(uname -s) $(uname -r)"

	OSVER=$(uname -r)
	case "$OSVER" in
	7.8 | 7.9 | 8.*) check_ok "release $OSVER is supported" ;;
	*) check_warn "release $OSVER is untested (suite targets 7.8 and 8.0)" ;;
	esac

	if [ ! -d /usr/X11R6 ]; then
		# X sets are numbered by release: xbase80 for 8.0, xbase78 for 7.8.
		_sets=$(printf '%s' "$OSVER" | tr -d '.')
		die "X11 file sets are missing: install xbase$_sets/xshare$_sets/xfont$_sets/xserv$_sets"
	fi
	check_ok "X11 file sets present"

	if [ ! -f /etc/installurl ] && [ -z "$MIRROR_URL" ]; then
		check_warn "/etc/installurl missing: will be created with the default mirror"
	fi

	need_cmd pkg_add
	need_cmd pkg_info
	need_cmd rcctl
	need_cmd doas
	return 0
}

# ---------------------------------------------------------------------------
# Backups
# ---------------------------------------------------------------------------
create_backup() {
	step "Backing up configuration"

	BACKUP_ROOT="/root/openbsd-kde-backup-$RUNSTAMP"
	BACKUP_MANIFEST="$BACKUP_ROOT/MANIFEST.tsv"

	if [ "$DRY_RUN" = 1 ]; then
		printf '%s[dry-run]%s mkdir -p %s\n' "$YELLOW" "$NC" "$BACKUP_ROOT"
		return 0
	fi

	mkdir -p "$BACKUP_ROOT" || die "cannot create $BACKUP_ROOT"
	umask 077
	: >"$BACKUP_MANIFEST"
	umask 022

	# Files this script may modify. rc.conf.local is included because
	# rollback.sh restores it (2.0.0 restored a file it never backed up).
	# Rows are typed so rollback knows what to do with a file that did not
	# exist before (ABSENT) and with the enabled/disabled state of a service.
	#   FILE<TAB>backup<TAB>target<TAB>sha256
	#   ABSENT<TAB>-<TAB>target<TAB>-
	#   SERVICE<TAB>-<TAB>daemon<TAB>on|off
	for _f in /etc/doas.conf /etc/sysctl.conf /etc/installurl \
		/etc/rc.conf.local /etc/wsconsctl.conf; do
		if [ -f "$_f" ]; then
			cp -p "$_f" "$BACKUP_ROOT/$(basename "$_f")" || die "cannot back up $_f"
			printf 'FILE	%s	%s	%s\n' \
				"$BACKUP_ROOT/$(basename "$_f")" "$_f" "$(_sha "$_f")" \
				>>"$BACKUP_MANIFEST"
			dbg "backed up $_f"
		else
			printf 'ABSENT	-	%s	-\n' "$_f" >>"$BACKUP_MANIFEST"
			dbg "absent before install: $_f"
		fi
	done

	# Services this script may enable, with the state to restore.
	for _s in messagebus xenodm; do
		if svc_enabled "$_s"; then
			printf 'SERVICE	-	%s	on\n' "$_s" >>"$BACKUP_MANIFEST"
		else
			printf 'SERVICE	-	%s	off\n' "$_s" >>"$BACKUP_MANIFEST"
		fi
	done

	pkg_info >"$BACKUP_ROOT/installed-packages.txt" 2>/dev/null || true
	ok "backup written to $BACKUP_ROOT"
	return 0
}

# ---------------------------------------------------------------------------
# Package mirror
# ---------------------------------------------------------------------------
setup_mirror() {
	step "Package mirror (/etc/installurl)"

	_current=$(cat /etc/installurl 2>/dev/null || true)

	if [ -n "$MIRROR_URL" ]; then
		if [ "$_current" = "$MIRROR_URL" ]; then
			info "mirror already set to $MIRROR_URL"
		else
			printf '%s\n' "$MIRROR_URL" | write_file /etc/installurl
			ok "mirror set to $MIRROR_URL"
		fi
		return 0
	fi

	if [ -n "$_current" ]; then
		info "keeping existing mirror: $_current (override with --mirror)"
		return 0
	fi

	printf '%s\n' "$MIRROR_DEFAULT" | write_file /etc/installurl
	ok "mirror set to $MIRROR_DEFAULT"
	return 0
}

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------
# install_one <pkg_add spec> <pkg_info expression>
install_one() {
	_spec=$1
	_expr=$2

	if pkg_installed "$_expr"; then
		dbg "already installed: $_spec"
		return 0
	fi
	if run pkg_add -I "$_spec"; then
		ok "installed: $_spec"
		return 0
	fi
	warn "could not install: $_spec"
	return 1
}

update_packages() {
	step "Updating installed packages"
	if run pkg_add -Iu; then
		ok "packages up to date"
	else
		warn "pkg_add -u reported errors; continuing (run 'doas pkg_check' to repair)"
	fi
	return 0
}

install_packages() {
	PKG_FAIL=0

	step "Installing KDE Plasma 6 (meta package pulls plasma-desktop/workspace/kwin)"
	install_one kde-plasma 'kde-plasma-*' || PKG_FAIL=$((PKG_FAIL + 1))
	install_one dbus 'dbus-*' || PKG_FAIL=$((PKG_FAIL + 1))
	install_one polkit 'polkit-*' || PKG_FAIL=$((PKG_FAIL + 1))
	install_one consolekit2 'consolekit2-*' || PKG_FAIL=$((PKG_FAIL + 1))

	if [ "$WANT_APPS" = 1 ]; then
		step "Installing desktop applications"
		install_one kate 'kate-*' || PKG_FAIL=$((PKG_FAIL + 1))
		install_one firefox 'firefox-*' || PKG_FAIL=$((PKG_FAIL + 1))
		install_one thunderbird 'thunderbird-*' || PKG_FAIL=$((PKG_FAIL + 1))
	fi

	if [ "$WANT_TOOLS" = 1 ]; then
		step "Installing optional CLI tools (tmux is already in base)"
		install_one git 'git-*' || PKG_FAIL=$((PKG_FAIL + 1))
		case "${OSVER:-}" in
		8.* | 9.* | [1-9][0-9].*)
			# 8.0 dropped the -no_x11 flavour and made the default vim build
			# console-only; -gtk3 is the only GUI flavour left.
			install_one vim 'vim-[0-9]*' || PKG_FAIL=$((PKG_FAIL + 1))
			;;
		*)
			install_one vim--no_x11 'vim-*-no_x11' || PKG_FAIL=$((PKG_FAIL + 1))
			;;
		esac
		install_one nano 'nano-*' || PKG_FAIL=$((PKG_FAIL + 1))
		install_one htop 'htop-*' || PKG_FAIL=$((PKG_FAIL + 1))
		install_one curl 'curl-*' || PKG_FAIL=$((PKG_FAIL + 1))
		install_one wget 'wget-*' || PKG_FAIL=$((PKG_FAIL + 1))
	fi

	# A failed polkit/consolekit2 used to pass silently: the verification only
	# looked at kde-plasma. Report the count here instead.
	if [ "$PKG_FAIL" -eq 0 ]; then
		check_ok "all requested packages installed"
	else
		check_fail "$PKG_FAIL package(s) failed to install (see log)"
	fi
	return 0
}

# ---------------------------------------------------------------------------
# doas
# ---------------------------------------------------------------------------
configure_doas() {
	step "doas (/etc/doas.conf)"

	if [ ! -f /etc/doas.conf ]; then
		run cp /etc/examples/doas.conf /etc/doas.conf ||
			die "cannot create /etc/doas.conf"
		ok "created /etc/doas.conf from /etc/examples"
	fi

	# "permit persist :wheel" is enough for interactive administration.
	# 2.0.0 added keepenv as well, which passes the caller's environment to
	# root commands for no benefit here.
	if grep -qE '^[[:space:]]*permit[[:space:]].*[[:space:]]:wheel([[:space:]]|$)' /etc/doas.conf; then
		info "a :wheel rule already exists, leaving it untouched"
	else
		append_block /etc/doas.conf 'permit persist :wheel' \
			'permit persist :wheel' &&
			ok "added: permit persist :wheel"
	fi

	if [ "$DRY_RUN" = 0 ]; then
		if doas -C /etc/doas.conf >/dev/null 2>&1; then
			check_ok "doas.conf parses (doas -C)"
		else
			check_fail "doas.conf does not parse - inspect /etc/doas.conf"
		fi
	fi

	if id -Gn "$(id -un 2>/dev/null || echo root)" 2>/dev/null | grep -qw wheel; then
		dbg "current user is in wheel"
	else
		check_warn "current user is not in wheel: doas will not work until added (usermod -G wheel <user>)"
	fi
	return 0
}

# ---------------------------------------------------------------------------
# D-Bus and xenodm
# ---------------------------------------------------------------------------
configure_dbus() {
	step "D-Bus session bus (messagebus)"

	if svc_enabled messagebus; then
		info "messagebus already enabled"
		return 0
	fi
	if run rcctl enable messagebus; then
		ok "messagebus enabled"
	else
		check_fail "could not enable messagebus"
	fi
	return 0
}

configure_xenodm() {
	step "Display manager (xenodm)"

	if svc_enabled xenodm; then
		info "xenodm already enabled"
	else
		run rcctl enable xenodm && ok "xenodm enabled"
	fi

	# The session itself is defined by ~/.xsession (written by setup-user.sh).
	# xenodm has no session chooser, so nothing else is required here.
	info "session comes from ~/.xsession - run setup-user.sh as your user"
	return 0
}

# ---------------------------------------------------------------------------
# Touchpad
# ---------------------------------------------------------------------------
configure_touchpad() {
	[ "$TOUCHPAD" = no ] && {
		info "touchpad: skipped (--no-touchpad)"
		return 0
	}
	step "Touchpad (wscons tap-to-click)"

	if ! have wsconsctl; then
		check_warn "wsconsctl not found, touchpad left untouched"
		return 0
	fi

	if ! wsconsctl -n mouse.tp.tapping >/dev/null 2>&1; then
		if [ "$TOUCHPAD" = yes ]; then
			check_warn "no touchpad detected; writing the setting anyway (harmless)"
		else
			info "no touchpad detected, leaving /etc/wsconsctl.conf untouched"
			return 0
		fi
	fi

	if append_block /etc/wsconsctl.conf 'mouse.tp.tapping' \
		'mouse.tp.tapping=1'; then
		ok "mouse.tp.tapping=1 added to /etc/wsconsctl.conf (needs a reboot)"
	fi
	# Apply now as well, so a reboot is not strictly required.
	if [ "$DRY_RUN" = 0 ] && wsconsctl -n mouse.tp.tapping >/dev/null 2>&1; then
		run wsconsctl mouse.tp.tapping=1 || warn "could not apply tapping at runtime"
	fi
	return 0
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
verify_installation() {
	step "Verifying installation"

	if pkg_installed 'kde-plasma-*'; then
		check_ok "kde-plasma installed ($(pkg_info -e 'kde-plasma-*' | head -1 | awk '{print $1}'))"
	else
		check_fail "kde-plasma is not installed"
	fi

	if [ -x /usr/local/bin/startplasma-x11 ]; then
		check_ok "session binary present: startplasma-x11"
	else
		check_fail "missing /usr/local/bin/startplasma-x11 (setup-user.sh needs it)"
	fi

	# rcctl check means "is it running"; a freshly configured box is not
	# running it yet, so ask whether the service is ENABLED.
	if svc_enabled messagebus; then
		check_ok "messagebus (D-Bus) enabled"
	else
		check_fail "messagebus is not enabled"
	fi

	if svc_enabled xenodm; then
		check_ok "xenodm enabled"
	else
		check_fail "xenodm is not enabled"
	fi

	if [ -f /etc/doas.conf ]; then
		check_ok "doas.conf exists"
	else
		check_fail "doas.conf missing"
	fi

	if [ -x /usr/local/bin/plasmashell ] || [ -x /usr/local/bin/kwin_x11 ]; then
		check_ok "Plasma binaries present"
	else
		check_fail "Plasma binaries missing (plasma-desktop/plasma-workspace)"
	fi
	return 0
}

# ---------------------------------------------------------------------------
main() {
	parse_args "$@"

	if [ -z "$LOG_FILE" ] && [ "$DRY_RUN" = 0 ] && [ "$(id -u)" -eq 0 ]; then
		LOG_FILE="/var/log/openbsd-kde-setup-$RUNSTAMP.log"
		: >"$LOG_FILE" 2>/dev/null || LOG_FILE=""
	fi
	[ -n "$LOG_FILE" ] && export LOG_FILE

	hdr "OpenBSD KDE Desktop Suite v$SUITE_VERSION - system setup"
	info "host: $(hostname)   user: $(id -un)   release: $(uname -r)"
	[ "$DRY_RUN" = 1 ] && warn "DRY RUN: nothing will be modified"

	preflight
	create_backup
	setup_mirror
	update_packages
	install_packages
	configure_doas
	configure_dbus
	configure_xenodm
	configure_touchpad

	if [ "$DRY_RUN" = 1 ]; then
		info "dry run: verification skipped (nothing was changed)"
		exit 0
	fi
	verify_installation

	if summary "system setup"; then
		hdr "System configuration complete"
		info "next: ksh setup-user.sh   (as your normal user, not root)"
		info "then: doas reboot"
		exit 0
	fi

	hdr "System configuration finished with failures"
	info "review the [fail] lines above and $LOG_FILE"
	exit 1
}

main "$@"
