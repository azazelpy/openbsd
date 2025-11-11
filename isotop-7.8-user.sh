#!/bin/ksh
#
# isotop-7.8-user.sh - Modernized OpenBSD 7.8+ Desktop Configuration (User)
# Original: isotop by 3hg/sp00cky
# Updated for OpenBSD 7.8 stable release with modern practices
# Usage: sh isotop-7.8-user.sh (run as regular user, not root)
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
USER_HOME="${HOME}"
CONFIG_DIR="${USER_HOME}/.config"
LOCAL_BIN="${USER_HOME}/.local/bin"
BACKUP_SUFFIX=".isotop-backup"

# Verify not running as root
check_user() {
    if [ "$(id -u)" = "0" ]; then
        print_error "This script should NOT be run as root"
        print_error "Run as your regular user account"
        exit 1
    fi
    print_success "Running as regular user: $(whoami)"
}

# Create necessary directories
setup_directories() {
    print_header "Creating user directories..."
    
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${LOCAL_BIN}"
    mkdir -p "${USER_HOME}/.cache"
    mkdir -p "${USER_HOME}/.local/share"
    
    print_success "User directories created"
}

# Setup X session configuration
setup_xsession() {
    print_header "Configuring X session (.xsession)..."
    
    XSESSION_FILE="${USER_HOME}/.xsession"
    
    # Backup existing xsession if it exists
    if [ -f "${XSESSION_FILE}" ]; then
        cp "${XSESSION_FILE}" "${XSESSION_FILE}${BACKUP_SUFFIX}"
        print_warning "Backed up existing .xsession"
    fi
    
    # Create new xsession for Xfce
    cat > "${XSESSION_FILE}" << 'EOF'
#!/bin/ksh
# Xfce Desktop Session Configuration
# Used by xenodm (display manager)

# Set up environment
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Initialize D-Bus
eval "$(dbus-launch --sh-syntax)"

# Start Xfce session
exec startxfce4
EOF
    
    chmod 700 "${XSESSION_FILE}"
    print_success "X session (.xsession) configured for Xfce"
}

# Setup alternative xinitrc for startx
setup_xinitrc() {
    print_header "Configuring .xinitrc (for startx)..."
    
    XINITRC_FILE="${USER_HOME}/.xinitrc"
    
    # Backup existing xinitrc if it exists
    if [ -f "${XINITRC_FILE}" ]; then
        cp "${XINITRC_FILE}" "${XINITRC_FILE}${BACKUP_SUFFIX}"
        print_warning "Backed up existing .xinitrc"
    fi
    
    # Create new xinitrc with fallback support
    cat > "${XINITRC_FILE}" << 'EOF'
#!/bin/ksh
# X11 Initialization Script
# Used by startx (manual X startup)

# Set up environment
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Initialize D-Bus
eval "$(dbus-launch --sh-syntax)"

# Try to launch Xfce, fall back to xterm if it fails
if command -v startxfce4 >/dev/null 2>&1; then
    exec startxfce4
else
    print "Warning: Xfce not found, launching xterm fallback" >&2
    exec xterm
fi
EOF
    
    chmod 700 "${XINITRC_FILE}"
    print_success ".xinitrc configured with fallback support"
}

# Shell profile configuration
setup_shell_profile() {
    print_header "Configuring shell profile (.kshrc / .profile)..."
    
    PROFILE_FILE="${USER_HOME}/.profile"
    KSHRC_FILE="${USER_HOME}/.kshrc"
    
    # Configure .profile if needed
    if ! grep -q "# isotop configuration" "${PROFILE_FILE}" 2>/dev/null; then
        cat >> "${PROFILE_FILE}" << 'EOF'

# isotop configuration
# User-specific environment variables and startup programs

# Add local bin to PATH
export PATH="${HOME}/.local/bin:${PATH}"

# Set default editor
export EDITOR="vim"
export VISUAL="vim"

# Set pager
export PAGER="less"

# Language and locale settings
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
EOF
        print_success "Shell profile (.profile) updated"
    else
        print_warning ".profile already configured"
    fi
    
    # Configure .kshrc if needed
    if ! grep -q "# isotop configuration" "${KSHRC_FILE}" 2>/dev/null; then
        cat >> "${KSHRC_FILE}" << 'EOF'

# isotop configuration
# Korn shell interactive configuration

# Aliases for common tasks
alias ll='ls -lah'
alias la='ls -la'
alias l='ls -CF'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias clear='clear && printf "\e[3J"'

# Git aliases (if git is installed)
if command -v git >/dev/null 2>&1; then
    alias gs='git status'
    alias ga='git add'
    alias gc='git commit'
    alias gp='git push'
    alias gl='git log --oneline'
fi

# Useful functions
# Create directory and enter it
mkcd() {
    mkdir -p "$@"
    cd "$@"
}

# Quick backup
bak() {
    cp -r "$1" "$1.backup-$(date +%s)"
}
EOF
        print_success ".kshrc configured with useful aliases and functions"
    else
        print_warning ".kshrc already configured"
    fi
}

# Xfce configuration defaults
setup_xfce_defaults() {
    print_header "Setting up Xfce defaults..."
    
    XFCE_CONFIG="${CONFIG_DIR}/xfce4"
    
    # Create Xfce config directory if it doesn't exist
    mkdir -p "${XFCE_CONFIG}/xfconf/xfce-perchannel-xml"
    
    # Create basic Xfce configuration if it doesn't exist
    if [ ! -f "${XFCE_CONFIG}/xfconf/xfce-perchannel-xml/xfwm4.xml" ]; then
        cat > "${XFCE_CONFIG}/xfconf/xfce-perchannel-xml/xfwm4.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="activate_raise" type="bool" value="true"/>
    <property name="click_to_focus" type="bool" value="true"/>
    <property name="cycling_raise" type="bool" value="true"/>
    <property name="move_opacity" type="int" value="100"/>
    <property name="placement_mode" type="string" value="center"/>
    <property name="show_dock_shadow" type="bool" value="true"/>
    <property name="theme" type="string" value="Default"/>
    <property name="title_alignment" type="string" value="center"/>
  </property>
</channel>
EOF
        print_success "Xfce window manager defaults created"
    fi
    
    # Xfce panel configuration
    if [ ! -f "${XFCE_CONFIG}/xfconf/xfce-perchannel-xml/xfce4-panel.xml" ]; then
        cat > "${XFCE_CONFIG}/xfconf/xfce-perchannel-xml/xfce4-panel.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="autohide" type="bool" value="false"/>
      <property name="height" type="int" value="30"/>
      <property name="length" type="int" value="100"/>
      <property name="mode" type="int" value="0"/>
      <property name="screen-position" type="int" value="9"/>
    </property>
  </property>
</channel>
EOF
        print_success "Xfce panel defaults created"
    fi
}

# Session autostart configuration
setup_autostart() {
    print_header "Setting up autostart directory..."
    
    AUTOSTART_DIR="${CONFIG_DIR}/autostart"
    mkdir -p "${AUTOSTART_DIR}"
    
    # Create a template autostart directory marker
    touch "${AUTOSTART_DIR}/.configured"
    
    print_success "Autostart directory configured at: ${AUTOSTART_DIR}"
    print_warning "Place .desktop files here to auto-launch applications on session start"
}

# Mouse and touchpad configuration
setup_input_devices() {
    print_header "Configuring input devices..."
    
    # Create .wsconsctl.conf for OpenBSD console (mouse/touchpad)
    if [ ! -f "${USER_HOME}/.wsconsctl.conf" ]; then
        cat > "${USER_HOME}/.wsconsctl.conf" << 'EOF'
# OpenBSD console input device configuration
# This file is read by wsconsctl at login

# Enable touchpad tapping (if available)
mouse.tp.tapping=1

# Adjust touchpad sensitivity (optional)
# mouse.tp.sensitivity=3
EOF
        print_success "Input device configuration created (.wsconsctl.conf)"
    fi
}

# Create quick launch scripts
setup_scripts() {
    print_header "Creating utility scripts..."
    
    # Lock screen script
    cat > "${LOCAL_BIN}/lock-screen" << 'EOF'
#!/bin/sh
# Simple screen lock using slock or xlock

if command -v slock >/dev/null 2>&1; then
    exec slock
elif command -v xlock >/dev/null 2>&1; then
    exec xlock -mode blank
else
    echo "No screen lock utility found. Install slock or xlock."
    exit 1
fi
EOF
    chmod 755 "${LOCAL_BIN}/lock-screen"
    print_success "Created lock-screen utility"
    
    # Session info script
    cat > "${LOCAL_BIN}/session-info" << 'EOF'
#!/bin/ksh
# Display current session information

echo "OpenBSD Session Information"
echo "================================"
echo "Hostname: $(hostname)"
echo "Username: $(whoami)"
echo "Home: ${HOME}"
echo "Shell: ${SHELL}"
echo "DISPLAY: ${DISPLAY:-not set}"
echo "X Session: ${DESKTOP_SESSION:-not set}"
echo "OpenBSD Version: $(uname -r)"
echo "Kernel: $(uname -s)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime | sed 's/.*up //' | sed 's/,[^,]*$//')"
EOF
    chmod 755 "${LOCAL_BIN}/session-info"
    print_success "Created session-info utility"
    
    # Package management helper
    cat > "${LOCAL_BIN}/update-packages" << 'EOF'
#!/bin/ksh
# Safe package update script

echo "OpenBSD Package Update Tool"
echo "============================"
echo ""
echo "This will update your installed packages."
echo "Requires doas/sudo access."
echo ""

doas pkg_add -Uu

echo ""
echo "Package update complete."
EOF
    chmod 755 "${LOCAL_BIN}/update-packages"
    print_success "Created update-packages utility"
}

# Verify configuration
verify_configuration() {
    print_header "Verifying configuration..."
    
    ERRORS=0
    
    # Check xsession
    if [ -f "${USER_HOME}/.xsession" ]; then
        print_success ".xsession configured"
    else
        print_error ".xsession not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check xinitrc
    if [ -f "${USER_HOME}/.xinitrc" ]; then
        print_success ".xinitrc configured"
    else
        print_error ".xinitrc not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Check config directory
    if [ -d "${CONFIG_DIR}" ]; then
        print_success "Configuration directory exists"
    else
        print_error "Configuration directory not found"
        ERRORS=$((ERRORS + 1))
    fi
    
    return ${ERRORS}
}

# Main installation
main() {
    clear
    echo ""
    echo "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo "${BLUE}║  isotop ${ISOTOP_VERSION} - OpenBSD 7.8 Desktop Setup   ║${NC}"
    echo "${BLUE}║  User Configuration Script                        ║${NC}"
    echo "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Pre-flight checks
    check_user
    
    # Create directories
    setup_directories
    
    # Configure X sessions
    setup_xsession
    setup_xinitrc
    
    # Configure shell
    setup_shell_profile
    
    # Setup Xfce
    setup_xfce_defaults
    setup_autostart
    
    # Input devices
    setup_input_devices
    
    # Utility scripts
    setup_scripts
    
    # Verify
    verify_configuration
    
    # Summary
    echo ""
    echo "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo "${GREEN}║  User Configuration Complete!                     ║${NC}"
    echo "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "${YELLOW}Configuration Summary:${NC}"
    echo "  • X Session:     ~/.xsession (for xenodm)"
    echo "  • X Init:        ~/.xinitrc (for startx)"
    echo "  • Shell Profile: ~/.profile & ~/.kshrc"
    echo "  • Config Dir:    ~/.config/"
    echo "  • Local Bin:     ~/.local/bin/"
    echo ""
    echo "${YELLOW}Next Steps:${NC}"
    echo "  1. Log out of your current session"
    echo "  2. At xenodm login, enter your credentials"
    echo "  3. Your Xfce desktop will start automatically"
    echo ""
    echo "${YELLOW}Alternative (startx):${NC}"
    echo "  • Log in via virtual terminal (Ctrl+Alt+F1)"
    echo "  • Type: ${BLUE}startx${NC}"
    echo "  • Your Xfce desktop will start manually"
    echo ""
    echo "${YELLOW}Utility Scripts Available:${NC}"
    echo "  • ~/.local/bin/lock-screen       - Lock your screen"
    echo "  • ~/.local/bin/session-info      - Display session info"
    echo "  • ~/.local/bin/update-packages   - Update packages safely"
    echo ""
    echo "${YELLOW}Backup Files:${NC}"
    echo "  • Previous configs backed up with .isotop-backup suffix"
    echo ""
}

# Run main function
main "$@"
