#!/bin/ksh
# ============================================================================
# OpenBSD KDE Desktop Suite - System Configuration
# ============================================================================
# Script: setup-root.sh
# Version: 2.0.0
# Purpose: System-wide KDE Plasma setup for OpenBSD 7.8
# Usage: doas ksh setup-root.sh
# ============================================================================
# Author: Friday (AI Assistant)
# Created: 2026-03-17
# License: MIT License
# Repository: https://github.com/azazelpy/openbsd
# ============================================================================

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
VERSION="2.0.0"
SCRIPT_NAME="setup-root.sh"
BACKUP_DIR="/root/openbsd-kde-backup-$(date +%Y%m%d-%H%M%S)"
MIRROR_URL="https://ftp.openbsd.org/pub/OpenBSD"

# ============================================================================
# COLOR OUTPUT FUNCTIONS
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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
		print_info "Usage: doas ksh $SCRIPT_NAME"
		exit 1
	fi
	print_success "Running as root"
}

check_version() {
	local current_version
	current_version=$(uname -r)
	
	if [ "$current_version" != "7.8" ]; then
		print_warning "This script is tested on OpenBSD 7.8"
		print_info "Current version: $current_version"
		print_warning "Proceeding anyway, but some packages may differ"
	else
		print_success "OpenBSD version: $current_version"
	fi
}

create_backup() {
	print_step "Creating configuration backups"
	
	mkdir -p "$BACKUP_DIR"
	
	# Backup critical configs
	for config in /etc/doas.conf /etc/sysctl.conf /etc/X11/xenodm/Xsetup_0; do
		if [ -f "$config" ]; then
			cp "$config" "$BACKUP_DIR/"
			print_success "Backed up: $config"
		fi
	done
	
	# Backup package list
	if [ -f /var/db/pkg/local.sqlite ]; then
		pkg_info > "$BACKUP_DIR/installed-packages.txt"
		print_success "Saved package list"
	fi
	
	print_success "Backups stored at: $BACKUP_DIR"
}

# ============================================================================
# MAIN INSTALLATION FUNCTIONS
# ============================================================================
setup_mirror() {
	print_step "Configuring package mirror"
	
	echo "$MIRROR_URL" > /etc/installurl
	print_success "Package mirror configured: $MIRROR_URL"
}

update_packages() {
	print_step "Updating all packages"
	
	if pkg_add -u; then
		print_success "All packages updated"
	else
		print_warning "Some packages may have failed to update (non-critical)"
	fi
}

install_kde_plasma() {
	print_header "Installing KDE Plasma Desktop"
	
	print_step "Installing KDE Plasma core"
	if pkg_add kde-plasma; then
		print_success "KDE Plasma installed"
	else
		print_error "Failed to install KDE Plasma"
		exit 1
	fi
	
	print_step "Installing KDE applications"
	pkg_add dolphin kate konsole firefox thunderbird || \
		print_warning "Some KDE apps may not be available"
	
	print_success "KDE applications installed"
}

install_system_daemons() {
	print_step "Installing system daemons"
	
	pkg_add messagebus polkit consolekit2
	
	print_success "System daemons installed"
	print_info "  - D-Bus (messagebus): Inter-process communication"
	print_info "  - PolicyKit (polkit): Authorization framework"
	print_info "  - ConsoleKit2 (consolekit2): User session tracking"
}

install_development_tools() {
	print_step "Installing development tools"
	
	pkg_add git vim nano htop tmux curl wget
	
	print_success "Development tools installed"
}

configure_doas() {
	print_step "Configuring doas"
	
	if [ ! -f /etc/doas.conf ]; then
		cp /etc/examples/doas.conf /etc/doas.conf
		print_success "Created doas.conf from example"
	fi
	
	# Add wheel persistence if not present
	if ! grep -q "permit persist keepenv :wheel" /etc/doas.conf 2>/dev/null; then
		echo "permit persist keepenv :wheel" >> /etc/doas.conf
		print_success "Added wheel persistence to doas.conf"
	else
		print_info "doas.conf already configured for wheel"
	fi
	
	# Validate doas.conf
	if doas -n true 2>/dev/null; then
		print_success "doas configuration validated"
	else
		print_warning "doas validation failed - check /etc/doas.conf"
	fi
}

configure_xenodm() {
	print_step "Configuring xenodm display manager"
	
	# Enable xenodm
	rcctl enable xenodm
	print_success "xenodm enabled"
	
	# Configure Xsetup_0 for KDE
	if [ -f /etc/X11/xenodm/Xsetup_0 ]; then
		# Add KDE session support
		if ! grep -q "kde" /etc/X11/xenodm/Xsetup_0 2>/dev/null; then
			cat >> /etc/X11/xenodm/Xsetup_0 << 'XSETUP'

# KDE Plasma support
if [ -x /usr/local/bin/startkde ]; then
	export PATH="/usr/local/bin:$PATH"
fi
XSETUP
			print_success "Added KDE support to Xsetup_0"
		fi
	fi
	
	# Start xenodm (will start on next boot)
	print_info "xenodm will start automatically on next boot"
}

configure_sysctl() {
	print_step "Applying system optimizations"
	
	# Create or update sysctl.conf
	if [ ! -f /etc/sysctl.conf ]; then
		touch /etc/sysctl.conf
	fi
	
	# Add optimizations if not present
	if ! grep -q "kern.somaxkva" /etc/sysctl.conf 2>/dev/null; then
		cat >> /etc/sysctl.conf << 'SYSCTL'

# KDE Plasma optimizations
kern.somaxkva=131072
kern.sbmax=262144
SYSCTL
		print_success "Added system optimizations to /etc/sysctl.conf"
	else
		print_info "System optimizations already present"
	fi
}

enable_services() {
	print_step "Enabling system services"
	
	# Enable D-Bus
	rcctl enable messagebus
	print_success "D-Bus enabled"
	
	# Enable PolicyKit
	rcctl enable polkit
	print_success "PolicyKit enabled"
	
	# Enable ConsoleKit2
	rcctl enable consolekit2
	print_success "ConsoleKit2 enabled"
	
	print_info "Services will start on next boot"
}

# ============================================================================
# VERIFICATION
# ============================================================================
verify_installation() {
	print_header "Verifying Installation"
	
	local pass=0
	local fail=0
	
	# Check KDE Plasma
	if pkg_info kde-plasma >/dev/null 2>&1; then
		print_success "KDE Plasma installed"
		pass=$((pass + 1))
	else
		print_error "KDE Plasma not found"
		fail=$((fail + 1))
	fi
	
	# Check xenodm
	if rcctl check xenodm >/dev/null 2>&1; then
		print_success "xenodm enabled"
		pass=$((pass + 1))
	else
		print_error "xenodm not enabled"
		fail=$((fail + 1))
	fi
	
	# Check D-Bus
	if rcctl check messagebus >/dev/null 2>&1; then
		print_success "D-Bus enabled"
		pass=$((pass + 1))
	else
		print_error "D-Bus not enabled"
		fail=$((fail + 1))
	fi
	
	# Check doas
	if [ -f /etc/doas.conf ]; then
		print_success "doas configured"
		pass=$((pass + 1))
	else
		print_error "doas not configured"
		fail=$((fail + 1))
	fi
	
	# Summary
	printf "\n"
	print_header "Verification Summary"
	printf "%sPassed: %d%s\n" "$GREEN" "$pass" "$NC"
	printf "%sFailed: %d%s\n" "$RED" "$fail" "$NC"
	
	if [ "$fail" -gt 0 ]; then
		print_warning "Some checks failed - review output above"
		return 1
	else
		print_success "All checks passed"
		return 0
	fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
main() {
	print_header "OpenBSD KDE Desktop Suite v$VERSION"
	print_info "System Configuration Script"
	print_info "Running as: $(whoami)"
	print_info "Hostname: $(hostname)"
	
	# Pre-flight checks
	check_root
	check_version
	
	# Backup existing configuration
	create_backup
	
	# System configuration
	setup_mirror
	update_packages
	
	# Install KDE Plasma
	install_kde_plasma
	install_system_daemons
	install_development_tools
	
	# Configure system
	configure_doas
	configure_xenodm
	configure_sysctl
	enable_services
	
	# Verify installation
	if verify_installation; then
		print_header "System Configuration Complete"
		print_success "KDE Plasma is ready"
		printf "\n"
		print_info "Next steps:"
		print_info "  1. Run setup-user.sh as regular user"
		print_info "  2. Reboot: doas reboot"
		print_info "  3. Login via xenodm and select KDE Plasma"
		printf "\n"
		print_success "Installation successful!"
		exit 0
	else
		print_header "Installation Completed with Warnings"
		print_warning "Some checks failed - review output"
		print_info "You may proceed, but verify the failed items"
		exit 1
	fi
}

# Run main function
main "$@"
