# 🌐 OpenBSD KDE Desktop Suite

> **Modern, Clean, Professional KDE Plasma on OpenBSD 7.8**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OpenBSD](https://img.shields.io/badge/OpenBSD-7.8-fuchsia.svg)](https://www.openbsd.org)
[![KDE](https://img.shields.io/badge/KDE-Plasma%206-blue.svg)](https://kde.org)
[![Shell](https://img.shields.io/badge/Shell-ksh-444444.svg)](https://man.openbsd.org/ksh)

---

## 🎯 Overview

**OpenBSD KDE Desktop Suite** provides production-ready automation scripts for setting up a modern **KDE Plasma** desktop environment on OpenBSD 7.8.

Unlike Xfce (lightweight but basic), KDE Plasma offers:
- ✨ **Modern, polished interface** with animations and effects
- 🔧 **Extensive customization** without editing config files
- 📦 **Integrated ecosystem** (Dolphin, Kate, Konsole, etc.)
- 🎨 **Beautiful default theme** with dark mode support
- 🚀 **Excellent HiDPI support** for modern displays

All scripts are:
- ✅ **Syntax-validated** for ksh (OpenBSD shell)
- ✅ **Idempotent** - safe to run multiple times
- ✅ **Backup-first** - preserves existing configs
- ✅ **Well-documented** - inline comments and clear output
- ✅ **Tested** - on real OpenBSD 7.8 systems

---

## 📦 What's Included

| Script | Purpose | Run As | Time |
|--------|---------|--------|------|
| `setup-root.sh` | System-wide configuration | Root | 10-15 min |
| `setup-user.sh` | User desktop configuration | User | 5 min |
| `setup-vmware.sh` | VMware guest optimization | Root | 2 min |

---

## 🚀 Quick Start

### Prerequisites

1. **OpenBSD 7.8** installed with X11 file sets:
   - `xbase78`
   - `xshare78`
   - `xfont78`
   - `xserv78`

2. **Internet connectivity** for package downloads

3. **Root access** via `doas`

### Installation (15 minutes)

```sh
# 1. Clone repository
git clone https://github.com/azazelpy/openbsd.git
cd openbsd

# 2. System configuration (run as root)
doas ksh setup-root.sh

# 3. User configuration (run as regular user)
ksh setup-user.sh

# 4. Optional: VMware optimization (only if running in VMware)
doas ksh setup-vmware.sh

# 5. Reboot
doas reboot
```

After reboot:
1. Login via **xenodm** (display manager)
2. Select **KDE Plasma** session
3. Enjoy your modern OpenBSD desktop!

---

## 🛠️ Scripts Detail

### 1. setup-root.sh (System Configuration)

**Run:** `doas ksh setup-root.sh`

**What it does:**
- ✅ Configures package mirror (`/etc/installurl`)
- ✅ Updates all packages to latest versions
- ✅ Installs KDE Plasma desktop (`kde-plasma`)
- ✅ Installs KDE applications (Dolphin, Kate, Konsole, etc.)
- ✅ Sets up system daemons (D-Bus, PolicyKit, ConsoleKit2)
- ✅ Configures `doas` for privilege escalation
- ✅ Enables `xenodm` display manager
- ✅ Applies system optimizations (`/etc/sysctl.conf`)
- ✅ Creates configuration backups

**Packages installed:**
```
kde-plasma           # Full KDE Plasma desktop
kde-apps             # Core KDE applications
dolphin              # File manager
kate                 # Text editor
konsole              # Terminal emulator
firefox              # Web browser
thunderbird          # Email client
git                  # Version control
vim, nano            # Text editors
htop, tmux           # System tools
```

---

### 2. setup-user.sh (User Configuration)

**Run:** `ksh setup-user.sh` (NOT as root)

**What it does:**
- ✅ Creates `.xsession` for KDE Plasma (xenodm)
- ✅ Creates `.xinitrc` for `startx` fallback
- ✅ Configures `.profile` with environment variables
- ✅ Configures `.kshrc` with useful aliases
- ✅ Sets up KDE configuration directory
- ✅ Creates utility scripts (lock-screen, system-info)
- ✅ Configures touchpad tapping
- ✅ Applies KDE color scheme (dark mode)

**Files created:**
```
~/.xsession              # KDE session (xenodm)
~/.xinitrc               # X init (startx)
~/.profile               # Shell environment
~/.kshrc                 # Ksh aliases
~/.config/kdeglobals     # KDE global settings
~/.local/bin/            # Utility scripts
```

---

### 3. setup-vmware.sh (VMware Optimization)

**Run:** `doas ksh setup-vmware.sh` (only if running in VMware)

**What it does:**
- ✅ Installs VMware Tools (`vmware-tools`)
- ✅ Enables VMware services (`vmtoolsd`, `vmblock`)
- ✅ Configures automatic start at boot
- ✅ Optimizes display settings
- ✅ Enables copy-paste between host and guest

**Note:** Skip this script if running on bare metal or other virtualization.

---

## 🎨 KDE vs Xfce Comparison

| Feature | KDE Plasma | Xfce |
|---------|------------|------|
| **Visual Appeal** | ⭐⭐⭐⭐⭐ Modern, polished | ⭐⭐⭐ Basic, functional |
| **Customization** | ⭐⭐⭐⭐⭐ Extensive GUI options | ⭐⭐⭐ Requires config editing |
| **Resource Usage** | ~600MB RAM (idle) | ~400MB RAM (idle) |
| **HiDPI Support** | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐ Limited |
| **Default Apps** | Full suite (Dolphin, Kate, etc.) | Basic (Thunar, Mousepad) |
| **Theme Support** | Global themes, colors, icons | Per-component themes |
| **Effects** | Desktop effects, animations | Minimal effects |
| **Best For** | Modern desktop experience | Minimalist, low-resource |

**Recommendation:**
- Choose **KDE Plasma** if you want a modern, polished desktop with excellent HiDPI support
- Choose **Xfce** if you need minimal resource usage on older hardware

---

## 📋 Post-Installation

### First Login

1. At xenodm login screen, select your username
2. Click **Session** → Select **KDE Plasma**
3. Enter password and login
4. KDE Plasma desktop appears

### Recommended First Steps

1. **System Settings** → **Display Configuration**
   - Set resolution and scaling (especially for HiDPI displays)

2. **System Settings** → **Colors & Themes**
   - Choose Global Theme (Breeze Dark recommended)

3. **System Settings** → **Window Management**
   - Configure desktop effects (optional)

4. **System Settings** → **Shortcuts**
   - Customize keyboard shortcuts

### Useful Commands

```sh
# Show system information
~/.local/bin/system-info

# Lock screen
~/.local/bin/lock-screen

# Update all packages
doas pkg_add -u

# Check KDE version
pkg_info kde-plasma

# Restart KDE (if needed)
pkill ksmserver
```

---

## 🔧 Troubleshooting

### Issue: xenodm doesn't start

**Solution:**
```sh
# Check xenodm status
doas rcctl check xenodm

# Enable xenodm
doas rcctl enable xenodm

# Start xenodm
doas rcctl start xenodm
```

### Issue: KDE doesn't appear in session list

**Solution:**
```sh
# Verify KDE installation
pkg_info kde-plasma

# Reinstall if needed
doas pkg_add -u kde-plasma

# Check X session file
ls -la /usr/local/share/xsessions/
```

### Issue: No sound

**Solution:**
```sh
# Install PulseAudio
doas pkg_add pulseaudio

# Add user to audio group
doas usermod -G audio $(whoami)

# Reboot
doas reboot
```

### Issue: VMware copy-paste doesn't work

**Solution:**
```sh
# Verify VMware Tools installed
pkg_info vmware-tools

# Check services running
doas rcctl check vmtoolsd
doas rcctl check vmblock

# Restart services
doas rcctl restart vmtoolsd
doas rcctl restart vmblock
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| `README.md` | This file - quick start and overview |
| `INSTALL.md` | Detailed installation guide |
| `KDE-CUSTOMIZATION.md` | KDE Plasma customization guide |
| `TROUBLESHOOTING.md` | Common issues and solutions |
| `CHANGELOG.md` | Version history and changes |

---

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- Additional KDE customizations
- More utility scripts
- Documentation improvements
- Bug fixes and optimizations

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly on OpenBSD 7.8
5. Commit with clear messages
6. Submit a pull request

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

**TL;DR:** Use it, modify it, share it. Just don't hold us liable.

---

## 🙏 Acknowledgments

- **OpenBSD Team** - For creating the most secure operating system
- **KDE Community** - For the beautiful Plasma desktop
- **Isotop Project** ([sp00cky/isotop](https://github.com/sp00cky/isotop)) - Original inspiration for OpenBSD desktop automation scripts

---

## 📚 References

This project was inspired by:
- **Isotop** - OpenBSD desktop configuration suite (https://github.com/sp00cky/isotop)
- **OpenBSD FAQ** - Installation and configuration guides (https://www.openbsd.org/faq/)
- **KDE Documentation** - Plasma setup and customization (https://docs.kde.org/)

---

## 📊 Repository Stats

[![GitHub stars](https://img.shields.io/github/stars/azazelpy/openbsd?style=social)](https://github.com/azazelpy/openbsd/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/azazelpy/openbsd?style=social)](https://github.com/azazelpy/openbsd/network/members)
[![GitHub issues](https://img.shields.io/github/issues/azazelpy/openbsd)](https://github.com/azazelpy/openbsd/issues)

---

## 📞 Support

**Issues:** Use [GitHub Issues](https://github.com/azazelpy/openbsd/issues)

**Discussions:** Use [GitHub Discussions](https://github.com/azazelpy/openbsd/discussions)

**Documentation:** Check `INSTALL.md` and `TROUBLESHOOTING.md`

---

**Created with ❤️ for the OpenBSD community**

☘️ **Quality over speed. Professional setups take time.**

---

*Last updated: 2026-03-17*
*Version: 2.0.0 (KDE Plasma Edition)*
