# isotop 7.8 - OpenBSD 7.8 Desktop Installation Guide

**Modernized OpenBSD Desktop Configuration Toolkit**

Version: 7.8.1  
Target: OpenBSD 7.8 Stable Release  
Last Updated: November 2025

## Overview

isotop is an automated desktop configuration toolkit for OpenBSD that transforms a minimal installation into a fully-featured Xfce desktop environment. This modernized version is specifically optimized for OpenBSD 7.8 with current best practices.

**Key Improvements over Original isotop:**

- Uses modern `rcctl` daemon management instead of rc.conf.local file editing
- Leverages `/etc/installurl` for package mirror configuration
- Implements proper D-Bus/PolicyKit/ConsoleKit2 integration
- Enhanced power management with optimal apmd flags
- Comprehensive error checking and user feedback
- Automatic configuration backups
- Modern privilege escalation with doas instead of sudo
- X11 session management best practices
- Extensive inline documentation

## System Requirements

### Minimum Hardware
- **CPU:** Intel/AMD x86_64 or ARM64 (Raspberry Pi 5+)
- **RAM:** 2GB minimum (4GB+ recommended for comfortable use)
- **Storage:** 20GB free space
- **Display:** Any GPU supported by OpenBSD DRM drivers

### Software Prerequisites
- OpenBSD 7.8 stable release (freshly installed)
- Network connectivity (for package downloads)
- Sudo/doas access
- Shell: ksh (default), bash, or zsh

### Supported Architectures
- `amd64` (Intel/AMD 64-bit)
- `arm64` (Raspberry Pi 5, etc.)

## Installation Steps

### Phase 1: Base OpenBSD Installation

1. Download OpenBSD 7.8 installer from official mirrors
2. Create installation media (USB or ISO)
3. Boot and run the OpenBSD installer
4. **Important:** During installation, select the following file sets:
   - `base78` - Base system
   - `xbase78`, `xshare78`, `xfont78`, `xserv78` - X Window System
   - `game78`, `man78` (optional but recommended)

5. Complete installation and reboot

### Phase 2: Root Configuration

Execute the root configuration script with elevated privileges:

```bash
su -                          # Switch to root
cd /tmp
ftp https://your-mirror/isotop-7.8-root.sh
sh isotop-7.8-root.sh
```

**What this script does:**

- Verifies OpenBSD 7.8 installation
- Configures package mirror (/etc/installurl)
- Installs Xfce desktop environment and dependencies
- Installs system daemons (D-Bus, PolicyKit, ConsoleKit2)
- Configures apmd for power management
- Sets up doas privilege escalation
- Enables xenodm (graphical login manager)
- Applies system optimizations
- Creates configuration backups

**Script Output:**

```
═══════════════════════════════════════════════════════
  isotop 7.8.1 - OpenBSD 7.8 Desktop Setup
  Root Configuration Script
═══════════════════════════════════════════════════════

✓ Running as root
✓ OpenBSD version check passed
✓ Configuration backups created
...
✓ Installation Complete!

Next Steps:
  1. Run the user configuration script
  2. Configure user sessions
  3. Reboot the system
```

### Phase 3: User Configuration

Log out from root and run the user configuration as your regular user:

```bash
sh isotop-7.8-user.sh
```

**What this script does:**

- Creates user configuration directories (~/.config, ~/.local/bin)
- Sets up X session files (.xsession for xenodm, .xinitrc for startx)
- Configures shell profile (.profile, .kshrc) with environment variables
- Initializes Xfce configuration
- Creates utility scripts for common tasks
- Sets up autostart directory for applications

**Script Output:**

```
═══════════════════════════════════════════════════════
  isotop 7.8.1 - OpenBSD 7.8 Desktop Setup
  User Configuration Script
═══════════════════════════════════════════════════════

✓ Running as regular user: username
✓ User directories created
✓ X session (.xsession) configured for Xfce
...
✓ User Configuration Complete!

Configuration Summary:
  • X Session:     ~/.xsession (for xenodm)
  • X Init:        ~/.xinitrc (for startx)
  • Shell Profile: ~/.profile & ~/.kshrc
  • Config Dir:    ~/.config/
  • Local Bin:     ~/.local/bin/
```

### Phase 4: First Boot

```bash
doas reboot
```

After reboot, xenodm will present a graphical login screen. Enter your credentials and Xfce will start automatically.

## Installed Packages

### Desktop Environment
- `xfce` - Core Xfce desktop
- `xfce-extras` - Additional Xfce components
- `xfce4-panel` - Task bar and application launcher
- `xfce4-terminal` - Terminal emulator
- `xfce4-power-manager` - Power management integration

### System Services
- `messagebus` - D-Bus message bus (required for many applications)
- `polkit` - PolicyKit daemon (privilege escalation for graphical apps)
- `consolekit2` - Session management

### Development Tools
- `git` - Version control
- `vim` - Advanced text editor
- `nano` - Simple text editor
- `curl`, `wget` - Download utilities

### System Utilities
- `htop` - Interactive process monitor
- `tmux` - Terminal multiplexer

### Optional Packages (Not Installed)
To install additional applications:

```bash
doas pkg_add firefox          # Web browser
doas pkg_add thunderbird      # Email client
doas pkg_add gimp             # Image editor
doas pkg_add vlc              # Media player
doas pkg_add transmission-gtk # Torrent client
```

## Session Management

### Using xenodm (Graphical Login)
1. xenodm is enabled by default at boot
2. Login graphically with your username and password
3. Xfce desktop starts automatically

**Configuration:** `/etc/X11/xenodm/`

### Using startx (Manual X Startup)
1. Boot to text login
2. Login to your user account
3. Type: `startx`
4. Xfce desktop starts

**Configuration:** `~/.xinitrc`

## Power Management Configuration

The `apmd` daemon is configured with optimal settings for both laptops and desktops:

```
apmd flags: -A -a -z 5

-A  : Adaptive performance mode (scales CPU based on load)
-a  : Auto-suspend block when on AC power
-z 5: Auto-suspend at 5% battery level
```

### Laptop-Specific Adjustments

For laptops with advanced power management requirements:

```bash
# Set performance mode (maximum performance, higher power usage)
doas rcctl set apmd flags -H

# Set power-saving mode (lower performance, reduced power)
doas rcctl set apmd flags -L

# Disable auto-suspend at low battery
doas rcctl set apmd flags -A
```

Apply changes:
```bash
doas rcctl restart apmd
```

## Daemon Management

Modern OpenBSD uses `rcctl` for daemon management:

```bash
# Check service status
rcctl status xenodm

# Start service
doas rcctl start messagebus

# Stop service
doas rcctl stop messagebus

# Enable at boot
doas rcctl enable messagebus

# Disable at boot
doas rcctl disable messagebus

# List running services
doas rcctl ls on

# List stopped services
doas rcctl ls off
```

### Critical Daemons

| Daemon | Purpose | Required |
|--------|---------|----------|
| `xenodm` | Graphical login manager | Yes |
| `messagebus` | D-Bus message bus | Yes |
| `polkitd` | PolicyKit daemon | Yes |
| `consolekit` | Session management | Yes |
| `apmd` | Power management | Yes (laptop) |

## Privilege Escalation (doas)

OpenBSD's modern replacement for sudo is `doas`. Configuration is simpler and more secure.

### Basic Usage

```bash
# Run command as root
doas reboot

# Run shell as root
doas ksh

# Cached authentication (subsequent commands don't require password)
doas -L    # List cached entries
doas -l    # Check sudo status
```

### Configuration

Edit `/etc/doas.conf` (as root):

```bash
doas cp /etc/examples/doas.conf /etc/doas.conf
```

Default configuration allows wheel group:

```
permit persist keepenv :wheel
```

## Package Management

### Using /etc/installurl

Modern OpenBSD uses `/etc/installurl` instead of PKG_PATH:

```bash
# View current mirror
cat /etc/installurl

# Set specific mirror (root only)
doas tee /etc/installurl << EOF
https://ftp.openbsd.org/pub/OpenBSD
EOF
```

### Package Operations

```bash
# Install package
doas pkg_add firefox

# Remove package
doas pkg_delete firefox

# Update all packages
doas pkg_add -Uu

# Search for packages
pkg_info -Q firefox

# List installed packages
pkg_info
```

## User Utilities

The user configuration script creates helpful utilities in `~/.local/bin/`:

### lock-screen
Lock the screen (requires `slock` or `xlock`):
```bash
~/.local/bin/lock-screen
```

### session-info
Display current session information:
```bash
~/.local/bin/session-info
```

Output:
```
OpenBSD Session Information
================================
Hostname: myhost
Username: user
Home: /home/user
Shell: /bin/ksh
DISPLAY: :0
X Session: xfce
OpenBSD Version: 7.8
Kernel: OpenBSD
Architecture: amd64
Uptime: 2 days, 3 hours
```

### update-packages
Safe package update:
```bash
~/.local/bin/update-packages
```

## Troubleshooting

### X Won't Start

**Error:** "X server failed to start"

**Solution:**
1. Check if X11 file sets are installed:
   ```bash
   pkg_info | grep xbase
   ```
2. Install missing sets via sysupgrade (requires network):
   ```bash
   doas sysupgrade
   ```
3. Verify display server:
   ```bash
   ls -la /usr/X11R6/bin/X
   ```

### xenodm Login Loop

**Problem:** Can't login, returns to login prompt

**Solution:**
1. Check `.xsession` permissions:
   ```bash
   ls -la ~/.xsession
   # Should be: -rwx------
   ```
2. Verify `.xsession` syntax:
   ```bash
   bash -n ~/.xsession
   ```
3. Check X logs:
   ```bash
   cat ~/.local/share/xfce4/xfce4-session/xfce4-session.log
   ```

### D-Bus Not Running

**Error:** "Failed to connect to session bus"

**Solution:**
```bash
# Check D-Bus status
doas rcctl status messagebus

# Start D-Bus
doas rcctl start messagebus

# Ensure it's enabled at boot
doas rcctl enable messagebus
```

### No Audio

**Problem:** Sound not working

**Install:** `doas pkg_add alsa-utils alsa-plugins`

**Then:** Open Xfce Sound Settings (Applications > Settings > Sound)

### Touchpad Not Working

**Problem:** Touchpad unresponsive

**Check:** Configuration in `~/.wsconsctl.conf`:
```bash
cat ~/.wsconsctl.conf
```

**Enable tapping:**
```bash
echo "mouse.tp.tapping=1" >> ~/.wsconsctl.conf
```

### Slow Performance

**Check Memory:**
```bash
free -h
top
```

**Check Disk:**
```bash
df -h
```

**Optimize:** Reduce running services:
```bash
doas rcctl ls on
```

### Shutdown/Reboot Hangs

**Issue:** System hangs on shutdown

**Solution:**
1. Add user to operator group (already done by script)
2. Verify group membership:
   ```bash
   groups
   # Should include: operator wheel
   ```
3. Try clean shutdown:
   ```bash
   doas shutdown -h now
   ```

## Configuration Files Reference

### System Configuration

| File | Purpose |
|------|---------|
| `/etc/installurl` | Package mirror configuration |
| `/etc/doas.conf` | Privilege escalation settings |
| `/etc/X11/xenodm/` | Display manager configuration |
| `/etc/sysctl.conf` | Kernel tuning parameters |

### User Configuration

| File | Purpose |
|------|---------|
| `~/.xsession` | X session startup (xenodm) |
| `~/.xinitrc` | X initialization (startx) |
| `~/.profile` | Shell environment |
| `~/.kshrc` | Korn shell configuration |
| `~/.config/xfce4/` | Xfce settings |
| `~/.local/bin/` | Personal scripts |

## System Backups

Automatic backups are created at:
```
/root/isotop-backup-YYYYMMDD-HHMMSS/
```

Contains backed-up configuration files before modifications.

Restore backed-up files:
```bash
doas cp /root/isotop-backup-DATE/doas.conf /etc/doas.conf
```

## Maintenance

### Regular Updates

Keep your system secure:

```bash
# Check for system patches
doas syspatch -c

# Apply patches
doas syspatch

# Upgrade packages
doas pkg_add -Uu

# Check release updates
doas sysupgrade -c

# Upgrade to new release
doas sysupgrade
```

### System Health Check

```bash
# View system logs
doas tail -f /var/log/messages

# Check dmesg for hardware issues
dmesg | tail -20

# Monitor resources
top
htop

# Check disk usage
df -h
du -sh ~/*
```

## Performance Tips

### For Low-Memory Systems (< 2GB)

1. **Disable unnecessary services:**
   ```bash
   doas rcctl disable consolekit
   doas rcctl disable polkitd
   ```

2. **Use lightweight window manager:**
   ```bash
   doas pkg_add cwm  # or i3, fluxbox
   echo "exec cwm" > ~/.xinitrc
   ```

3. **Reduce desktop effects** in Xfce Settings

### For SSD Systems

OpenBSD automatically optimizes for SSDs. No additional configuration needed.

### For Laptop Battery Life

The default apmd configuration is optimized for battery life:
- Adaptive CPU scaling enabled
- 5% battery reserve before shutdown
- Automatic suspend on battery at low power

## Security Hardening

### Basic Hardening

1. **Set strong passwords:**
   ```bash
   passwd  # Change your password
   ```

2. **Enable firewall:**
   ```bash
   doas rcctl enable pf
   doas rcctl start pf
   ```

3. **Configure SSH** (if needed):
   ```bash
   # Edit /etc/ssh/sshd_config
   doas rcctl reload sshd
   ```

4. **Disable unnecessary services:**
   ```bash
   doas rcctl disable sndiod  # If not using sound
   ```

## Community and Support

- **Official Site:** https://www.openbsd.org/
- **Manual Pages:** man.openbsd.org
- **OpenBSD Handbook:** openbsdhandbook.com
- **Forums:** daemonforums.org

## License and Attribution

This modernized isotop script is based on the original isotop project by sp00cky (3hg/isotop).

- Original isotop: https://framagit.org/3hg/isotop
- Modernization: November 2025
- License: Open-source (same as original)

## Version History

### 7.8.1 (November 2025)
- OpenBSD 7.8 optimization
- Modern rcctl daemon management
- Enhanced error handling and logging
- Configuration backup automation
- Improved documentation

### Original (2018)
- OpenBSD 6.5+ support
- Basic Xfce desktop setup
- Package installation automation

## Quick Reference Card

```
# Installation Quick Start
doas sh isotop-7.8-root.sh    # System setup (as root)
sh isotop-7.8-user.sh         # User setup (as user)
doas reboot                    # First boot

# Daily Commands
doas rcctl status xenodm       # Check display manager
doas rcctl start/stop SERVICE  # Control services
doas pkg_add -Uu              # Update packages
doas syspatch                 # Apply security patches
top                           # Monitor system

# Troubleshooting
dmesg | tail                  # Hardware messages
cat ~/.local/share/xfce4/... # Xfce session logs
rcctl ls on                   # List active services
```

---

**Last Updated:** November 10, 2025  
**OpenBSD Version:** 7.8 Stable  
**Status:** Production-ready
