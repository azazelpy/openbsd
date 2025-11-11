#!/bin/ksh

# isotop-7.8-root.sh - OpenBSD 7.8 Desktop Setup (Root)
# Usage: doas ksh isotop-7.8-root.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
print_header() {
	printf "%s%s%s\n" "$BLUE" "==> $1" "$NC"
}

print_success() {
	printf "%s%s%s\n" "$GREEN" "OK $1" "$NC"
}

print_warning() {
	printf "%s%s%s\n" "$YELLOW" "! $1" "$NC"
}

print_error() {
	printf "%s%s%s\n" "$RED" "ERROR $1" "$NC"
}

# Check root
if [ "$(id -u)" != "0" ]; then
	print_error "Must run as root"
	exit 1
fi
print_success "Running as root"

# Check version
CURRENT_VERSION=$(uname -r)
print_header "OpenBSD version: $CURRENT_VERSION"
print_success "Version check passed"

# Backup configs
print_header "Creating backups..."
BACKUP_DIR="/root/isotop-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
[ -f /etc/doas.conf ] && cp /etc/doas.conf "$BACKUP_DIR/" || true
[ -f /etc/X11/xenodm/Xsetup_0 ] && cp /etc/X11/xenodm/Xsetup_0 "$BACKUP_DIR/" || true
[ -f /etc/sysctl.conf ] && cp /etc/sysctl.conf "$BACKUP_DIR/" || true
print_success "Backups at: $BACKUP_DIR"

# Setup mirror
print_header "Configuring package mirror..."
echo "https://ftp.openbsd.org/pub/OpenBSD" > /etc/installurl
print_success "Mirror configured"

# Update packages
print_header "Updating packages..."
pkg_add -u
print_success "Packages updated"

# Install packages
print_header "Installing Xfce desktop..."
pkg_add xfce xfce-extras xfce4-panel xfce4-terminal xfce4-power-manager

print_header "Installing daemons..."
pkg_add messagebus polkit consolekit2

print_header "Installing tools..."
pkg_add git vim nano htop tmux curl wget

print_success "Packages installed"

# Doas
print_header "Configuring doas..."
if [ ! -f /etc/doas.conf ]; then
	cp /etc/examples/doas.conf /etc/doas.conf
	print_success "Created doas.conf"
fi

if ! grep -q "permit persist keepenv :wheel" /etc/doas.conf; then
	echo "permit persist keepenv :wheel" >> /etc/doas.conf
	print_success "Add
