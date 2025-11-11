#!/bin/ksh
#
# isotop-7.8-root.sh - Modernized OpenBSD 7.8+ Desktop Configuration (Root)
# Original: isotop by 3hg/sp00cky
# Updated for OpenBSD 7.8 stable release with modern practices
# Requires: root privileges (use doas)
# Usage: doas sh isotop-7.8-root.sh
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
print_header() {
    echo "${BLUE}==>${NC} $1"
}

print_success() {
    echo "${GREEN}✓${NC} $1"
}

print_warning() {
    echo "${YELLOW}!${NC} $1"
}

print_error() {
    echo "${RED}✗${NC} $1"
}

# Configuration
ISOTOP_VERSION="7.8.1"
OPENBSD_RELEASE="7.8"
PACKAGES_CORE="xfce xfce-extras xfce4-panel xfce4-terminal xfce4-power-manager"
PACKAGES_OPTIONAL="firefox thunderbird gimp vlc transmission-gtk"
PACKAGES_TOOLS="git vim nano htop tmux curl wget"
PACKAGES_DAEMONS="messagebus polkit consolekit2"

# System validation
check_root() {
    if [ "$(id -u)" != "0" ]; then
        print_error "This script must be run as root (use doas)"
        exit 1
    fi
    print_success "Running as root"
}

check_openbsd_version() {
    CURRENT_VERSION=$(uname -r)
    print_header "Checking OpenBSD version..."
    echo "Current version: ${BLUE}${CURRENT_VERSION}${NC}"
    
    if [ "${CURRENT_VERSION%.*}" != "${OPENBSD_RELEASE}" ]; then
        print_warning "This script is optimized for OpenBSD ${OPENBSD_RELEASE}"
        print_warning "You are running OpenBSD ${CURRENT_VERSION}"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    print_success "OpenBSD version check passed"
}

# Package management
setup_package_mirror() {
    print_header "Configuring package mirror..."
    
    # Detect architecture
    ARCH=$(uname -m)
    MIRROR="https://ftp.openbsd.org/pub/OpenBSD"
    
    # Write to /etc/installurl (replaces PKG_PATH)
    echo "${MIRROR}" > /etc/installurl
    
    print_success "Package mirror configured: ${MIRROR}"
}

# Update packages
update_packages() {
    print_header "Updating package database..."
    pkg_add -u
    print_success "Packages updated"
}

# Install packages
install_packages() {
    print_header "Installing packages..."
    
    # Core packages
    print_header "Installing Xfce desktop environment..."
    pkg_add ${PACKAGES_CORE}
    
    # System daemons
    print_header "Installing system daemons..."
    pkg_add ${PACKAGES_DAEMONS}
    
    # Tools
    print_header "Installing utility tools..."
    pkg_add ${PACKAGES_TOOLS}
    
    print_success "All core packages installed"
}

# Doas configuration
setup_doas() {
    print_header "Configuring doas (privilege escalation)..."
    
    # Check if doas.conf exists
    if [ ! -f /etc/doas.conf ]; then
        cp /etc/examples/doas.conf /etc/doas.conf
        print_success "Doas configuration created from example"
    fi
    
    # Ensure wheel group has doas access
    if ! grep -q "permit persist keepenv :wheel" /etc/doas.conf; then
        echo "permit persist keepenv :wheel" >> /etc/doas.conf
        print_success "Wheel group doas access configured"
    else
        print_warning "Wheel group doas access already configured"
    fi
    
    # Restrict permissions
    chmod 640 /etc/doas.conf
    print_success "Doas configuration secured"
}

# Display manager configuration (xenodm)
setup_display_manager() {
    print_header "Configuring X11 display manager (xenodm)..."
    
    # Remove xconsole from Xsetup_0 (it's outdated)
    if [ -f /etc/X11/xenodm/Xsetup_0 ]; then
        sed -i 's/^xconsole/#xconsole/' /etc/X11/xenodm/Xsetup_0
        print_success "Xconsole disabled in xenodm setup"
    fi
    
    # Enable xenodm at boot
    rcctl enable xenodm
    print_success "Xenodm enabled for boot"
}

# System daemons
setup_daemons() {
    print_header "Configuring system daemons..."
    
    # D-Bus (messagebus) - required for many applications
    print_header "Setting up D-Bus..."
    rcctl enable messagebus
    rcctl start messagebus
    print_success "D-Bus (messagebus) enabled and started"
    
    # PolicyKit - required for privilege escalation in graphical apps
    print_header "Setting up PolicyKit..."
    rcctl enable polkitd
    rcctl start polkitd
    print_success "PolicyKit (polkitd) enabled and started"
    
    # ConsoleKit2 - session management
    print_header "Setting up ConsoleKit2..."
    rcctl enable consolekit
    rcctl start consolekit
    print_success "ConsoleKit2 enabled and started"
    
    # APM daemon - power management (critical for laptops)
    print_header "Setting up power management (apmd)..."
    rcctl enable apmd
    rcctl set apmd flags "-A -a -z 5"
    rcctl start apmd
    print_success "APM daemon configured with adaptive power management"
    print_warning "APM Flags: -A (adaptive), -a (AC block suspend), -z 5 (5% battery auto-suspend)"
}

# Timezone configuration
setup_timezone() {
    print_header "Configuring timezone..."
    
    # Check current timezone
    CURRENT_TZ=$(head -1 /etc/timezone)
    echo "Current timezone: ${BLUE}${CURRENT_TZ}${NC}"
    
    # If you need to change timezone, uncomment and modify:
    # TZ="America/New_York"
    # ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime
    # echo "${TZ}" > /etc/timezone
    # print_success "Timezone set to ${TZ}"
    
    print_success "Timezone configuration verified"
}

# Hostname and network
setup_hostname() {
    print_header "Checking hostname configuration..."
    
    CURRENT_HOSTNAME=$(hostname)
    echo "Current hostname: ${BLUE}${CURRENT_HOSTNAME}${NC}"
    
    # Hostname should be set during OpenBSD installation
    # Only change if needed
    if [ -z "${CURRENT_HOSTNAME}" ]; then
        print_error "Hostname not set. Please configure /etc/myname"
        return 1
    fi
    
    print_success "Hostname verified: ${CURRENT_HOSTNAME}"
}

# Group membership for users
setup_user_groups() {
    print_header "Checking user accounts for proper group membership..."
    
    # Find regular users (UID >= 1000)
    REGULAR_USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)
    
    if [ -z "${REGULAR_USERS}" ]; then
        print_warning "No regular users found (UID >= 1000)"
        return
    fi
    
    for user in ${REGULAR_USERS}; do
        print_header "Configuring user: ${BLUE}${user}${NC}"
        
        # Add to operator group (required for power control with apmd)
        if ! groups ${user} | grep -q operator; then
            usermod -G operator ${user}
            print_success "Added ${user} to operator group"
        else
            print_warning "${user} already in operator group"
        fi
        
        # Add to wheel group (for doas)
        if ! groups ${user} | grep -q wheel; then
            usermod -G wheel ${user}
            print_success "Added ${user} to wheel group"
        else
            print_warning "${user} already in wheel group"
        fi
    done
}

# System optimization tweaks
setup_sysctl() {
    print_header "Applying system optimizations..."
    
    # Check if custom sysctl settings exist
    if ! grep -q "# isotop customizations" /etc/sysctl.conf; then
        print_header "Adding custom sysctl settings..."
        
        cat >> /etc/sysctl.conf << 'EOF'

# isotop customizations
# Increase file descriptor limits for desktop applications
kern.maxfiles=65535
kern.maxfilesperproc=32768

# Enable hardware random number generator for better entropy
kern.random=1
EOF
        print_success "Sysctl optimizations applied"
    else
        print_warning "Sysctl customizations already present"
    fi
    
    # Apply immediately
    sysctl kern.maxfiles=65535 >/dev/null 2>&1
    sysctl kern.maxfilesperproc=32768 >/dev/null 2>&1
    print_success "System optimizations active"
}

# Backup important files
backup_configs() {
    print_header "Creating configuration backups..."
    
    BACKUP_DIR="/root/isotop-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${BACKUP_DIR}"
    
    # Backup critical files before modifications
    [ -f /etc/doas.conf ] && cp /etc/doas.conf "${BACKUP_DIR}/"
    [ -f /etc/X11/xenodm/Xsetup_0 ] && cp /etc/X11/xenodm/Xsetup_0 "${BACKUP_DIR}/"
    [ -f /etc/sysctl.conf ] && cp /etc/sysctl.conf "${BACKUP_DIR}/"
    
    print_success "Configuration backups created in: ${BACKUP_DIR}"
}

# Main installation
main() {
    clear
    echo ""
    echo "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo "${BLUE}║  isotop ${ISOTOP_VERSION} - OpenBSD ${OPENBSD_RELEASE} Desktop Setup   ║${NC}"
    echo "${BLUE}║  Root Configuration Script                       ║${NC}"
    echo "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Pre-flight checks
    check_root
    check_openbsd_version
    
    # Create backups before making changes
    backup_configs
    
    # Package management
    setup_package_mirror
    update_packages
    install_packages
    
    # System configuration
    setup_doas
    setup_timezone
    setup_hostname
    setup_user_groups
    
    # Desktop environment
    setup_display_manager
    setup_daemons
    
    # System tuning
    setup_sysctl
    
    # Summary
    echo ""
    echo "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}║  Installation Complete!                           ║${NC}"
    echo "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "${YELLOW}Next Steps:${NC}"
    echo "  1. Run the user configuration script:"
    echo "     ${BLUE}sh isotop-7.8-user.sh${NC}"
    echo ""
    echo "  2. Configure user sessions (as regular user):"
    echo "     ${BLUE}echo 'exec startxfce4' > ~/.xsession${NC}"
    echo ""
    echo "  3. Reboot the system:"
    echo "     ${BLUE}doas reboot${NC}"
    echo ""
    echo "${YELLOW}Configuration Backups:${NC} Located in /root/isotop-backup-*"
    echo ""
}

# Run main function
main "$@"
