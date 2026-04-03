#!/bin/ksh
# ============================================================================
# OpenBSD KDE Desktop Suite - Configuration Rollback
# ============================================================================
# Script: rollback.sh
# Version: 1.0.0
# Purpose: Restore previous configuration from backup
# Usage: doas ksh rollback.sh [backup_directory]
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
SCRIPT_NAME="rollback.sh"
DEFAULT_BACKUP_PATTERN="/root/openbsd-kde-backup-*"

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

print_step() {
    printf "\n%s%s%s\n" "$BLUE" "==> $1" "$NC"
}

print_success() {
    printf "%s✓ %s%s\n" "$GREEN" "$1" "$NC"
}

print_warning() {
    printf "%s⚠ %s%s\n" "$YELLOW" "$1" "$NC"
}

print_error() {
    printf "%s✗ ERROR: %s%s\n" "$RED" "$1" "$NC"
}

print_info() {
    printf "%sℹ %s%s\n" "$MAGENTA" "$1" "$NC"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

check_root() {
    if [ "$(id -u)" != "0" ]; then
        print_error "This script must be run as root"
        print_info "Usage: doas ksh $SCRIPT_NAME [backup_directory]"
        exit 1
    fi
    print_success "Running as root"
}

list_backups() {
    print_step "Available backups"
    
    local backups
    backups=$(ls -lt $DEFAULT_BACKUP_PATTERN 2>/dev/null || true)
    
    if [ -z "$backups" ]; then
        print_error "No backups found"
        print_info "Backups should be in: /root/openbsd-kde-backup-*"
        exit 1
    fi
    
    printf "\n%s\n" "$backups"
    printf "\n"
}

restore_file() {
    local backup_file="$1"
    local original_path="$2"
    
    if [ -f "$backup_file" ]; then
        cp "$backup_file" "$original_path"
        print_success "Restored: $original_path"
    else
        print_warning "Not found: $backup_file"
    fi
}

# ============================================================================
# ROLLBACK FUNCTIONS
# ============================================================================

restore_configuration() {
    local backup_dir="$1"
    
    print_step "Restoring configuration from: $backup_dir"
    
    # Restore doas.conf
    if [ -f "$backup_dir/doas.conf" ]; then
        restore_file "$backup_dir/doas.conf" "/etc/doas.conf"
    fi
    
    # Restore sysctl.conf
    if [ -f "$backup_dir/sysctl.conf" ]; then
        restore_file "$backup_dir/sysctl.conf" "/etc/sysctl.conf"
    fi
    
    # Restore Xsetup_0
    if [ -f "$backup_dir/Xsetup_0" ]; then
        restore_file "$backup_dir/Xsetup_0" "/etc/X11/xenodm/Xsetup_0"
    fi
    
    # Restore rc.conf.local
    if [ -f "$backup_dir/rc.conf.local" ]; then
        restore_file "$backup_dir/rc.conf.local" "/etc/rc.conf.local"
    fi
    
    # Restore fstab (if backed up)
    if [ -f "$backup_dir/fstab" ]; then
        restore_file "$backup_dir/fstab" "/etc/fstab"
    fi
    
    print_success "Configuration restoration complete"
}

restart_services() {
    print_step "Restarting services"
    
    # Restart xenodm
    if rcctl check xenodm >/dev/null 2>&1; then
        rcctl restart xenodm
        print_success "Restarted: xenodm"
    fi
    
    # Restart dbus
    if rcctl check messagebus >/dev/null 2>&1; then
        rcctl restart messagebus
        print_success "Restarted: messagebus"
    fi
    
    # Restart polkitd
    if rcctl check polkitd >/dev/null 2>&1; then
        rcctl restart polkitd
        print_success "Restarted: polkitd"
    fi
    
    # Restart consolekit2
    if rcctl check consolekit2 >/dev/null 2>&1; then
        rcctl restart consolekit2
        print_success "Restarted: consolekit2"
    fi
    
    print_success "Services restarted"
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

main() {
    print_header "OpenBSD KDE Desktop - Configuration Rollback"
    printf "Version: %s\n" "$VERSION"
    printf "Date: %s\n" "$(date)"
    
    check_root
    
    # Check if backup directory provided
    if [ $# -gt 0 ]; then
        BACKUP_DIR="$1"
        if [ ! -d "$BACKUP_DIR" ]; then
            print_error "Backup directory not found: $BACKUP_DIR"
            exit 1
        fi
    else
        # Find latest backup
        BACKUP_DIR=$(ls -t $DEFAULT_BACKUP_PATTERN 2>/dev/null | head -1)
        
        if [ -z "$BACKUP_DIR" ]; then
            print_error "No backups found"
            list_backups
            exit 1
        fi
    fi
    
    print_info "Using backup: $BACKUP_DIR"
    printf "\n"
    
    # Confirm rollback
    print_warning "This will restore previous configuration"
    printf "Backup: %s\n" "$BACKUP_DIR"
    printf "\n"
    printf "Continue? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_info "Rollback cancelled"
        exit 0
    fi
    
    # Perform rollback
    restore_configuration "$BACKUP_DIR"
    restart_services
    
    print_header "Rollback Complete"
    
    printf "%sConfiguration restored successfully!%s\n" "$GREEN" "$NC"
    printf "\n"
    printf "Next steps:\n"
    printf "1. Verify system is working correctly\n"
    printf "2. If needed, reboot: doas reboot\n"
    printf "3. Review restored configuration files\n"
    printf "\n"
    printf "Restored files:\n"
    printf "  - /etc/doas.conf\n"
    printf "  - /etc/sysctl.conf\n"
    printf "  - /etc/X11/xenodm/Xsetup_0\n"
    printf "  - /etc/rc.conf.local\n"
    printf "  - /etc/fstab (if backed up)\n"
    printf "\n"
}

# Run main function
main
