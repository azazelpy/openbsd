#!/bin/ksh
# ============================================================================
# OpenBSD KDE Desktop Suite - Installation Validation
# ============================================================================
# Script: validate-install.sh
# Version: 1.0.0
# Purpose: Verify KDE Plasma installation is working correctly
# Usage: ksh validate-install.sh
# ============================================================================
# Author: Friday (AI Assistant)
# Created: 2026-04-03
# License: MIT License
# Repository: https://github.com/azazelpy/openbsd
# ============================================================================

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
VERSION="1.0.0"
SCRIPT_NAME="validate-install.sh"
PASSED=0
FAILED=0
WARNINGS=0

# ============================================================================
# COLOR OUTPUT FUNCTIONS
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    printf "\n%s%s%s\n" "$CYAN" "========================================" "$NC"
    printf "%s%s%s\n" "$CYAN" "  $1" "$NC"
    printf "%s%s%s\n" "$CYAN" "========================================" "$NC"
}

print_check() {
    printf "%s[CHECK] %s%s" "$BLUE" "$1" "$NC"
}

print_pass() {
    printf " %s✓ PASS%s\n" "$GREEN" "$NC"
    PASSED=$((PASSED + 1))
}

print_fail() {
    printf " %s✗ FAIL%s\n" "$RED" "$NC"
    FAILED=$((FAILED + 1))
}

print_warn() {
    printf " %s⚠ WARN%s\n" "$YELLOW" "$NC"
    WARNINGS=$((WARNINGS + 1))
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

check_kde_packages() {
    print_check "KDE Plasma packages installed... "
    
    if pkg_info kde-plasma >/dev/null 2>&1; then
        print_pass
    else
        print_fail
        echo "  KDE Plasma package not found. Run setup-root.sh first."
    fi
}

check_kde_applications() {
    print_check "KDE applications installed... "
    
    local apps_ok=true
    
    for app in dolphin kate konsole; do
        if ! pkg_info "$app" >/dev/null 2>&1; then
            apps_ok=false
            break
        fi
    done
    
    if $apps_ok; then
        print_pass
    else
        print_warn
        echo "  Some KDE applications missing (optional)"
    fi
}

check_xenodm() {
    print_check "Xenodm display manager configured... "
    
    if [ -f /etc/X11/xenodm/Xsetup_0 ] && grep -q "startplasma-x11\|startkde" /etc/X11/xenodm/Xsetup_0 2>/dev/null; then
        print_pass
    else
        print_warn
        echo "  Xenodm may not be configured for KDE"
    fi
}

check_dbus() {
    print_check "D-Bus daemon enabled... "
    
    if grep -q "messagebus" /etc/rc.conf.local 2>/dev/null; then
        print_pass
    else
        print_fail
        echo "  D-Bus not enabled. Run: echo 'messagebus=YES' >> /etc/rc.conf.local"
    fi
}

check_policykit() {
    print_check "PolicyKit daemon enabled... "
    
    if grep -q "polkitd" /etc/rc.conf.local 2>/dev/null; then
        print_pass
    else
        print_fail
        echo "  PolicyKit not enabled. Run: echo 'polkitd=YES' >> /etc/rc.conf.local"
    fi
}

check_consolekit() {
    print_check "ConsoleKit2 daemon enabled... "
    
    if grep -q "consolekit2" /etc/rc.conf.local 2>/dev/null; then
        print_pass
    else
        print_fail
        echo "  ConsoleKit2 not enabled. Run: echo 'consolekit2=YES' >> /etc/rc.conf.local"
    fi
}

check_doas() {
    print_check "Doas configured correctly... "
    
    if [ -f /etc/doas.conf ] && grep -q "permit" /etc/doas.conf 2>/dev/null; then
        print_pass
    else
        print_warn
        echo "  Doas may not be configured"
    fi
}

check_kde_config() {
    print_check "KDE configuration files exist... "
    
    local kde_config_ok=true
    
    for config in "$HOME/.config/kwinrc" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"; do
        if [ ! -f "$config" ]; then
            kde_config_ok=false
            break
        fi
    done
    
    if $kde_config_ok; then
        print_pass
    else
        print_warn
        echo "  KDE user config not found (will be created on first login)"
    fi
}

check_dolphin() {
    print_check "Dolphin file manager available... "
    
    if [ -x /usr/local/bin/dolphin ]; then
        print_pass
    else
        print_warn
        echo "  Dolphin not found (optional)"
    fi
}

check_kate() {
    print_check "Kate text editor available... "
    
    if [ -x /usr/local/bin/kate ]; then
        print_pass
    else
        print_warn
        echo "  Kate not found (optional)"
    fi
}

check_konsole() {
    print_check "Konsole terminal available... "
    
    if [ -x /usr/local/bin/konsole ]; then
        print_pass
    else
        print_warn
        echo "  Konsole not found (optional)"
    fi
}

check_backup_exists() {
    print_check "Configuration backups exist... "
    
    if ls /root/openbsd-kde-backup-* >/dev/null 2>&1; then
        print_pass
        local latest_backup
        latest_backup=$(ls -t /root/openbsd-kde-backup-* | head -1)
        echo "  Latest: $latest_backup"
    else
        print_warn
        echo "  No backups found (run setup scripts first)"
    fi
}

check_disk_space() {
    print_check "Sufficient disk space... "
    
    local available_space
    available_space=$(df -k / | tail -1 | awk '{print $4}')
    
    # KDE requires ~2GB minimum
    if [ "$available_space" -gt 2097152 ]; then
        print_pass
        echo "  Available: $((available_space / 1024 / 1024))GB"
    else
        print_fail
        echo "  Low disk space: $((available_space / 1024))MB (need 2GB+)"
    fi
}

check_openbsd_version() {
    print_check "OpenBSD version compatibility... "
    
    local version
    version=$(uname -r)
    
    if [ "$version" = "7.8" ]; then
        print_pass
        echo "  Version: $version (supported)"
    else
        print_warn
        echo "  Version: $version (tested on 7.8)"
    fi
}

# ============================================================================
# MAIN VALIDATION
# ============================================================================

main() {
    print_header "OpenBSD KDE Desktop - Installation Validation"
    printf "Version: %s\n" "$VERSION"
    printf "Date: %s\n" "$(date)"
    printf "User: %s\n" "$(whoami)"
    printf "Host: %s\n" "$(hostname)"
    
    print_header "Running Validation Checks"
    
    check_openbsd_version
    check_kde_packages
    check_kde_applications
    check_xenodm
    check_dbus
    check_policykit
    check_consolekit
    check_doas
    check_kde_config
    check_dolphin
    check_kate
    check_konsole
    check_backup_exists
    check_disk_space
    
    print_header "Validation Summary"
    
    printf "%sPassed:%s   %d\n" "$GREEN" "$NC" "$PASSED"
    printf "%sFailed:%s   %d\n" "$RED" "$NC" "$FAILED"
    printf "%sWarnings:%s %d\n" "$YELLOW" "$NC" "$WARNINGS"
    printf "\n"
    
    if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        printf "%s✓ Installation validated successfully!%s\n" "$GREEN" "$NC"
        printf "\n"
        printf "Next steps:\n"
        printf "1. Reboot: doas reboot\n"
        printf "2. Login via xenodm\n"
        printf "3. Select KDE Plasma session\n"
        printf "4. Enjoy your OpenBSD KDE desktop!\n"
        printf "\n"
        exit 0
    elif [ $FAILED -eq 0 ]; then
        printf "%s✓ Installation looks good with minor warnings%s\n" "$YELLOW" "$NC"
        printf "\n"
        printf "Review warnings above. System should be functional.\n"
        printf "\n"
        exit 0
    else
        printf "%s✗ Installation has issues that need attention%s\n" "$RED" "$NC"
        printf "\n"
        printf "Review failed checks above and re-run setup scripts if needed.\n"
        printf "\n"
        exit 1
    fi
}

# Run main function
main
