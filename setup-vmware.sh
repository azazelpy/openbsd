#!/bin/ksh
# ============================================================================
# OpenBSD KDE Desktop Suite - VMware guest integration (run as root)
# ============================================================================
# Script:  setup-vmware.sh
# Version: 2.1.0
# Purpose: install the VMware host-integration helper on an OpenBSD guest
# Usage:   doas ksh setup-vmware.sh
# License: MIT License - https://github.com/azazelpy/openbsd
# ============================================================================
#
# What changed from 2.0.0, and why:
#   * there is no "vmware-tools" package in the OpenBSD 7.8 index; vmt(4) is
#     a kernel driver in the base system (shutdown/reboot requests, host
#     clock as a time delta), so nothing has to be installed for it
#   * host mouse integration comes from the "vmwh" package, started inside
#     the X session - setup-user.sh already adds that line to ~/.xsession
#   * "rcctl enable vmtoolsd/vmblock" and "rcctl set vmwgfx flags ON" named
#     services that do not exist; the 20-vmwgfx.conf Xorg file used a driver
#     name X does not ship and pinned three fixed resolutions
# ============================================================================

set -eu
set -o pipefail 2>/dev/null || true

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

usage() {
	cat <<'USAGE'
setup-vmware.sh - VMware guest integration for the OpenBSD KDE suite

Usage: doas ksh setup-vmware.sh [options]

Options:
  -n, --dry-run   print every action, change nothing
  -y, --yes       assume "yes" for prompts
  -v, --verbose   show extra detail
  -h, --help      this help

Installs: vmwh (host mouse integration helper), then verifies vmt(4).
X configuration is left alone: OpenBSD autoconfigures the display, and a
hard-coded xorg.conf is the usual cause of "wrong resolution after reboot".
USAGE
}

while [ $# -gt 0 ]; do
	case "$1" in
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
	-h | --help)
		usage
		exit 0
		;;
	*) die "unknown option: $1 (try --help)" ;;
	esac
done

main() {
	hdr "OpenBSD KDE Desktop Suite v$SUITE_VERSION - VMware guest"
	[ "$DRY_RUN" = 1 ] && warn "DRY RUN: nothing will be modified"

	step "Pre-flight checks"
	[ "$(id -u)" -eq 0 ] || die "run as root: doas ksh setup-vmware.sh"
	require_openbsd
	ok "OpenBSD $(uname -r)"

	if is_vmware; then
		ok "VMware guest detected"
	else
		warn "no VMware signature found in dmesg or hw.vendor"
		ask_yes "continue anyway?" || {
			info "cancelled"
			exit 1
		}
	fi

	step "Kernel side (vmt)"
	if dmesg 2>/dev/null | grep -q '^vmt0'; then
		ok "vmt0 attached: host clock, shutdown and reboot requests are handled"
	else
		warn "vmt0 not present in dmesg: add 'vmt0 at pvbus0' to /etc/... or check the VM config"
	fi

	step "Userspace helper (vmwh)"
	if pkg_installed 'vmwh-*'; then
		info "vmwh already installed"
	else
		run pkg_add -I vmwh || die "could not install vmwh"
		ok "vmwh installed"
	fi

	if [ -x /usr/local/bin/vmwh ]; then
		check_ok "/usr/local/bin/vmwh present"
	else
		check_fail "/usr/local/bin/vmwh missing after install"
	fi

	step "Session integration"
	info "vmwh must run inside the X session. setup-user.sh writes:"
	printf '  [ -x /usr/local/bin/vmwh ] && /usr/local/bin/vmwh &\n'
	info "re-run 'ksh setup-user.sh' as your user if ~/.xsession lacks that line"

	step "Verification"
	if grep -rqs 'vmwh' /root /home/*/.xsession 2>/dev/null; then
		check_ok "at least one ~/.xsession launches vmwh"
	else
		check_warn "no ~/.xsession launches vmwh yet (run setup-user.sh)"
	fi
	check_ok "no rc.d service is required on OpenBSD for this"

	if summary "VMware guest"; then
		hdr "VMware guest ready"
		info "log out and back in (or reboot) to start vmwh with the session"
		exit 0
	fi
	exit 1
}

main "$@"
