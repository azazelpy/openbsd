#!/bin/ksh
# ============================================================================
# OpenBSD KDE Desktop Suite - User Configuration
# ============================================================================
# Script: setup-user.sh
# Version: 2.0.0
# Purpose: User-level KDE Plasma configuration for OpenBSD 7.8
# Usage: ksh setup-user.sh (NOT as root)
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
SCRIPT_NAME="setup-user.sh"

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
check_not_root() {
	if [ "$(id -u)" = "0" ]; then
		print_error "Do NOT run this script as root"
		print_info "Usage: ksh $SCRIPT_NAME"
		exit 1
	fi
	print_success "Running as user: $(whoami)"
}

create_directory() {
	local dir="$1"
	if [ ! -d "$dir" ]; then
		mkdir -p "$dir"
		print_success "Created: $dir"
	else
		print_info "Exists: $dir"
	fi
}

backup_file() {
	local file="$1"
	if [ -f "$file" ]; then
		cp "$file" "${file}.bak"
		print_success "Backed up: $file"
	fi
}

# ============================================================================
# USER CONFIGURATION FUNCTIONS
# ============================================================================
setup_directories() {
	print_step "Creating user directories"
	
	create_directory "$HOME/.config"
	create_directory "$HOME/.local"
	create_directory "$HOME/.local/bin"
	create_directory "$HOME/.cache"
	create_directory "$HOME/.local/share"
	create_directory "$HOME/.config/autostart"
	
	print_success "User directories ready"
}

setup_xsession() {
	print_step "Configuring .xsession (xenodm login)"
	
	backup_file "$HOME/.xsession"
	
	cat > "$HOME/.xsession" << 'XSESSION'
#!/bin/ksh
# OpenBSD KDE Plasma Session
# Used by xenodm display manager

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Start D-Bus if not running
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
	eval "$(dbus-launch --sh-syntax)"
fi

# Start KDE Plasma
exec startkde
XSESSION
	
	chmod 700 "$HOME/.xsession"
	print_success ".xsession configured for KDE Plasma"
}

setup_xinitrc() {
	print_step "Configuring .xinitrc (startx fallback)"
	
	backup_file "$HOME/.xinitrc"
	
	cat > "$HOME/.xinitrc" << 'XINITRC'
#!/bin/ksh
# OpenBSD KDE Plasma X Session
# Used by startx command

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Start D-Bus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
	eval "$(dbus-launch --sh-syntax)"
fi

# Start KDE Plasma or fallback to xterm
if command -v startkde >/dev/null 2>&1; then
	exec startkde
else
	print_error "KDE Plasma not found"
	print_info "Installing: pkg_add kde-plasma"
	exec xterm
fi
XINITRC
	
	chmod 700 "$HOME/.xinitrc"
	print_success ".xinitrc configured"
}

setup_profile() {
	print_step "Configuring .profile"
	
	backup_file "$HOME/.profile"
	
	# Add configuration if not present
	if ! grep -q "OpenBSD KDE" "$HOME/.profile" 2>/dev/null; then
		cat >> "$HOME/.profile" << 'PROFILE'

# OpenBSD KDE Desktop Suite configuration
# Added by setup-user.sh

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Default editor
export EDITOR="vim"
export VISUAL="vim"

# Pager
export PAGER="less"
export LESS="-R"

# Locale
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# KDE integration
export KDE_HOME="$HOME/.kde"
PROFILE
		print_success ".profile configured"
	else
		print_info ".profile already configured"
	fi
}

setup_kshrc() {
	print_step "Configuring .kshrc"
	
	backup_file "$HOME/.kshrc"
	
	# Add configuration if not present
	if ! grep -q "OpenBSD KDE" "$HOME/.kshrc" 2>/dev/null; then
		cat >> "$HOME/.kshrc" << 'KSHRC'

# OpenBSD KDE Desktop Suite - Shell aliases
# Added by setup-user.sh

# List commands
alias ll='ls -lah'
alias la='ls -la'
alias l='ls -CF'
alias lt='ls -lht'
alias ltr='ls -lhtr'

# Color grep
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Safe operations
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# System info
alias myip='curl -s ifconfig.me'
alias weather='curl -s wttr.in'

# KDE helpers
alias kde-restart='pkill ksmserver'
alias kde-version='pkg_info kde-plasma'

# Useful functions
mkcd() {
	mkdir -p "$1" && cd "$1"
}

extract() {
	if [ -f "$1" ]; then
		case "$1" in
			*.tar.bz2) tar xjf "$1" ;;
			*.tar.gz) tar xzf "$1" ;;
			*.bz2) bunzip2 "$1" ;;
			*.rar) unrar e "$1" ;;
			*.gz) gunzip "$1" ;;
			*.tar) tar xf "$1" ;;
			*.tbz2) tar xjf "$1" ;;
			*.tgz) tar xzf "$1" ;;
			*.zip) unzip "$1" ;;
			*.Z) uncompress "$1" ;;
			*.7z) 7z x "$1" ;;
			*) echo "Don't know how to extract '$1'" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}
KSHRC
		print_success ".kshrc configured"
	else
		print_info ".kshrc already configured"
	fi
}

setup_kde_config() {
	print_step "Configuring KDE settings"
	
	create_directory "$HOME/.config"
	
	# Global KDE settings (dark theme by default)
	if [ ! -f "$HOME/.config/kdeglobals" ]; then
		cat > "$HOME/.config/kdeglobals" << 'KDEGLOBAL'
[General]
ColorScheme=BreezeDark
Name=KDE Dark
shadeSortColumn=true
terminalApplication=konsole
widgetStyle=Breeze

[KDE]
widgetStyle=Breeze
colorScheme=BreezeDark

[WM]
activeBlend=59,151,252
activeBackground=35,38,41
activeForeground=239,240,241
inactiveBlend=100,100,100
inactiveBackground=54,54,54
inactiveForeground=180,180,180
KDEGLOBAL
		print_success "KDE dark theme configured"
	else
		print_info "KDE config already exists"
	fi
	
	# Dolphin file manager settings
	create_directory "$HOME/.config/dolphinrc"
	
	print_success "KDE configuration ready"
}

create_utility_scripts() {
	print_step "Creating utility scripts"
	
	# System info script
	cat > "$HOME/.local/bin/system-info" << 'SYSINFO'
#!/bin/ksh
# OpenBSD System Information

echo "OpenBSD System Information"
echo "=========================="
echo ""
echo "Hostname:    $(hostname)"
echo "User:        $(whoami)"
echo "OpenBSD:     $(uname -r)"
echo "Arch:        $(uname -m)"
echo "CPU:         $(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"
echo "Memory:      $(sysctl -n hw.physmem 2>/dev/null | awk '{printf "%.0f MB", $1/1024/1024}' || echo 'Unknown')"
echo ""
echo "Desktop:     KDE Plasma"
echo "KDE Version: $(pkg_info kde-plasma 2>/dev/null | head -1 | awk '{print $2}' || echo 'Unknown')"
echo ""
echo "Uptime:      $(uptime | sed 's/.*up //' | sed 's/,.*$//')"
echo ""
SYSINFO
	chmod 755 "$HOME/.local/bin/system-info"
	print_success "Created: system-info"
	
	# Lock screen script
	cat > "$HOME/.local/bin/lock-screen" << 'LOCKSCREEN'
#!/bin/sh
# Screen locker for KDE

if command -v kscreenlocker >/dev/null 2>&1; then
	kscreenlocker
elif command -v slock >/dev/null 2>&1; then
	slock
else
	xlock -mode blank
fi
LOCKSCREEN
	chmod 755 "$HOME/.local/bin/lock-screen"
	print_success "Created: lock-screen"
	
	# KDE restart script
	cat > "$HOME/.local/bin/kde-restart" << 'KDERESTART'
#!/bin/sh
# Restart KDE Plasma (use with caution)

echo "Restarting KDE Plasma..."
echo "All KDE applications will close."
echo ""
read -p "Continue? (y/N) " confirm
case "$confirm" in
	[yY][eE][sS]|[yY])
		pkill ksmserver
		;;
	*)
		echo "Cancelled"
		;;
esac
KDERESTART
	chmod 755 "$HOME/.local/bin/kde-restart"
	print_success "Created: kde-restart"
	
	# Package update script
	cat > "$HOME/.local/bin/update-system" << 'UPDATE'
#!/bin/ksh
# System update helper

echo "Updating OpenBSD packages..."
echo ""
doas pkg_add -u
echo ""
echo "Update complete!"
UPDATE
	chmod 755 "$HOME/.local/bin/update-system"
	print_success "Created: update-system"
}

setup_input_devices() {
	print_step "Configuring input devices"
	
	# Touchpad tapping
	if [ ! -f "$HOME/.wsconsctl.conf" ]; then
		cat > "$HOME/.wsconsctl.conf" << 'WSCONS'
# Touchpad configuration
mouse.tp.tapping=1
mouse.mousepad.horizontal_scrolling=1
WSCONS
		print_success "Touchpad tapping enabled"
	else
		print_info ".wsconsctl.conf already exists"
	fi
}

setup_autostart() {
	print_step "Configuring autostart"
	
	create_directory "$HOME/.config/autostart"
	
	print_success "Autostart directory ready"
	print_info "Place .desktop files in ~/.config/autostart/"
}

# ============================================================================
# VERIFICATION
# ============================================================================
verify_configuration() {
	print_header "Verifying Configuration"
	
	local pass=0
	local fail=0
	
	# Check .xsession
	if [ -f "$HOME/.xsession" ]; then
		print_success ".xsession exists"
		pass=$((pass + 1))
	else
		print_error ".xsession missing"
		fail=$((fail + 1))
	fi
	
	# Check .xinitrc
	if [ -f "$HOME/.xinitrc" ]; then
		print_success ".xinitrc exists"
		pass=$((pass + 1))
	else
		print_error ".xinitrc missing"
		fail=$((fail + 1))
	fi
	
	# Check .profile
	if [ -f "$HOME/.profile" ]; then
		print_success ".profile exists"
		pass=$((pass + 1))
	else
		print_error ".profile missing"
		fail=$((fail + 1))
	fi
	
	# Check .kshrc
	if [ -f "$HOME/.kshrc" ]; then
		print_success ".kshrc exists"
		pass=$((pass + 1))
	else
		print_error ".kshrc missing"
		fail=$((fail + 1))
	fi
	
	# Check KDE config
	if [ -d "$HOME/.config" ]; then
		print_success "Config directory exists"
		pass=$((pass + 1))
	else
		print_error "Config directory missing"
		fail=$((fail + 1))
	fi
	
	# Check utility scripts
	if [ -x "$HOME/.local/bin/system-info" ]; then
		print_success "Utility scripts created"
		pass=$((pass + 1))
	else
		print_error "Utility scripts missing"
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
	print_info "User Configuration Script"
	print_info "Running as: $(whoami)"
	print_info "Home: $HOME"
	
	# Pre-flight check
	check_not_root
	
	# Setup user environment
	setup_directories
	setup_xsession
	setup_xinitrc
	setup_profile
	setup_kshrc
	setup_kde_config
	create_utility_scripts
	setup_input_devices
	setup_autostart
	
	# Verify configuration
	if verify_configuration; then
		print_header "User Configuration Complete"
		print_success "KDE Plasma is ready for your user"
		printf "\n"
		print_info "Next steps:"
		print_info "  1. Reboot: doas reboot"
		print_info "  2. Login via xenodm"
		print_info "  3. Select 'KDE Plasma' session"
		print_info "  4. Enjoy your modern OpenBSD desktop!"
		printf "\n"
		print_info "Utility scripts available:"
		print_info "  system-info   - Show system information"
		print_info "  lock-screen   - Lock your screen"
		print_info "  kde-restart   - Restart KDE Plasma"
		print_info "  update-system - Update all packages"
		printf "\n"
		print_success "Configuration successful!"
		exit 0
	else
		print_header "Configuration Completed with Warnings"
		print_warning "Some checks failed - review output"
		exit 1
	fi
}

# Run main function
main "$@"
