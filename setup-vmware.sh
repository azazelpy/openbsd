#!/bin/ksh
# ============================================================================
# OpenBSD KDE Desktop Suite - VMware Tools
# ============================================================================
# Script: setup-vmware.sh
# Version: 2.0.0
# Purpose: VMware guest optimization for OpenBSD 7.8
# Usage: doas ksh setup-vmware.sh (ONLY if running in VMware)
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
SCRIPT_NAME="setup-vmware.sh"

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
	printf "%sℹ %s%s\n" "$CYAN" "$1" "$NC"
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

detect_vmware() {
	print_step "Detecting virtualization"
	
	# Check dmesg for VMware
	if dmesg | grep -qi "vmware"; then
		print_success "VMware detected"
		return 0
	fi
	
	# Check sysctl for VMware
	if sysctl -n hw.vendor 2>/dev/null | grep -qi "vmware"; then
		print_success "VMware detected (via sysctl)"
		return 0
	fi
	
	# Check for VMware tools already installed
	if pkg_info vmware-tools >/dev/null 2>&1; then
		print_warning "VMware Tools already installed"
		return 0
	fi
	
	print_error "VMware not detected"
	print_info "This script should only run on VMware virtual machines"
	print_info "If you're sure you're on VMware, you can proceed anyway"
	printf "\n"
	read -p "Continue anyway? (y/N) " confirm
	case "$confirm" in
		[yY][eE][sS]|[yY])
			print_info "Proceeding despite detection failure"
			return 0
			;;
		*)
			print_info "Aborting"
			exit 1
			;;
	esac
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================
install_vmware_tools() {
	print_step "Installing VMware Tools"
	
	if pkg_add vmware-tools; then
		print_success "VMware Tools installed"
	else
		print_error "Failed to install VMware Tools"
		print_info "Check that package mirrors are configured"
		exit 1
	fi
}

enable_vmware_services() {
	print_step "Enabling VMware services"
	
	# Enable vmtoolsd (VMware Tools daemon)
	rcctl enable vmtoolsd
	print_success "vmtoolsd enabled"
	
	# Enable vmblock (file system blocking)
	rcctl enable vmblock
	print_success "vmblock enabled"
	
	# Enable vmwgfx (VMware graphics driver)
	if rcctl set vmwgfx flags ON 2>/dev/null; then
		print_success "vmwgfx enabled"
	else
		print_info "vmwgfx not available (may not be needed)"
	fi
	
	print_info "Services will start on next boot"
}

configure_display() {
	print_step "Configuring display settings"
	
	# Create Xorg configuration for VMware
	if [ ! -d /etc/X11/xorg.conf.d ]; then
		mkdir -p /etc/X11/xorg.conf.d
		print_success "Created Xorg config directory"
	fi
	
	# VMware-specific Xorg config
	cat > /etc/X11/xorg.conf.d/20-vmwgfx.conf << 'XORG'
Section "Device"
    Identifier "VMware"
    Driver "vmwgfx"
    Option "Accelerate3D" "true"
    Option "EnablePageFlip" "true"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "VMware"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080" "1280x1024" "1024x768"
    EndSubSection
EndSection
XORG
	
	print_success "VMware display configured"
}

configure_copy_paste() {
	print_step "Configuring copy-paste integration"
	
	print_info "VMware Tools provides copy-paste between host and guest"
	print_info "Ensure 'Guest Isolation' is enabled in VMware settings"
	print_info "  - Edit VM Settings → Options → Guest Isolation"
	print_info "  - Enable: Drag and Drop"
	print_info "  - Enable: Copy and Paste"
}

optimize_vm_settings() {
	print_step "Applying VM optimizations"
	
	# Suggest VM settings
	print_info "Recommended VMware settings:"
	print_info "  Processors: 2 or more"
	print_info "  Memory: 2048 MB or more"
	print_info "  Display: Accelerate 3D graphics"
	print_info "  Network: NAT or Bridged"
	print_info "  Disk: SCSI or NVMe controller"
}

# ============================================================================
# VERIFICATION
# ============================================================================
verify_installation() {
	print_header "Verifying VMware Tools"
	
	local pass=0
	local fail=0
	
	# Check vmware-tools package
	if pkg_info vmware-tools >/dev/null 2>&1; then
		print_success "VMware Tools installed"
		pass=$((pass + 1))
	else
		print_error "VMware Tools not found"
		fail=$((fail + 1))
	fi
	
	# Check vmtoolsd service
	if rcctl check vmtoolsd >/dev/null 2>&1; then
		print_success "vmtoolsd enabled"
		pass=$((pass + 1))
	else
		print_error "vmtoolsd not enabled"
		fail=$((fail + 1))
	fi
	
	# Check vmblock service
	if rcctl check vmblock >/dev/null 2>&1; then
		print_success "vmblock enabled"
		pass=$((pass + 1))
	else
		print_error "vmblock not enabled"
		fail=$((fail + 1))
	fi
	
	# Summary
	printf "\n"
	print_header "Verification Summary"
	printf "%sPassed: %d%s\n" "$GREEN" "$pass" "$NC"
	printf "%sFailed: %d%s\n" "$RED" "$fail" "$NC"
	
	if [ "$fail" -gt 0 ]; then
		print_warning "Some checks failed"
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
	print_info "VMware Tools Configuration"
	print_info "Running as: $(whoami)"
	print_info "Hostname: $(hostname)"
	
	# Pre-flight checks
	check_root
	detect_vmware
	
	# Install and configure
	install_vmware_tools
	enable_vmware_services
	configure_display
	configure_copy_paste
	optimize_vm_settings
	
	# Verify installation
	if verify_installation; then
		print_header "VMware Tools Configuration Complete"
		print_success "VMware optimization complete"
		printf "\n"
		print_info "Next steps:"
		print_info "  1. Reboot: doas reboot"
		print_info "  2. After reboot, verify copy-paste works"
		print_info "  3. Adjust display resolution in System Settings"
		printf "\n"
		print_info "Troubleshooting:"
		print_info "  - Copy-paste: Enable in VMware VM settings"
		print_info "  - Display: Install VMware Tools on host if issues"
		print_info "  - Performance: Allocate more RAM/CPU to VM"
		printf "\n"
		print_success "VMware configuration successful!"
		exit 0
	else
		print_header "Configuration Completed with Warnings"
		print_warning "Some checks failed - review output"
		exit 1
	fi
}

# Run main function
main "$@"
