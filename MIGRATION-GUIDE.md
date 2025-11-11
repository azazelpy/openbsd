# Migration Guide: Original isotop → isotop 7.8

## For Users Upgrading from Original isotop

This guide explains the differences and changes in the modernized isotop 7.8 version.

### What Changed and Why

#### 1. Package Management: PKG_PATH → /etc/installurl

**Original isotop:**
```bash
export PKG_PATH=https://ftp.openbsd.org/pub/OpenBSD/6.6/packages/$(uname -m)
echo "export PKG_PATH=..." >> .profile
```

**isotop 7.8:**
```bash
echo "https://ftp.openbsd.org/pub/OpenBSD" > /etc/installurl
```

**Why?** Modern OpenBSD (7.0+) uses `/etc/installurl` as the standard package mirror configuration. It's simpler, centralized, and doesn't require environment variables.

#### 2. Daemon Management: rc.conf.local → rcctl

**Original isotop:**
```bash
echo "pkg_scripts=\"dbus_daemon avahi_daemon\"" >> /etc/rc.conf.local
echo "dbus_enable=YES" >> /etc/rc.conf.local
```

**isotop 7.8:**
```bash
rcctl enable messagebus
rcctl start messagebus
rcctl set apmd flags "-A -a -z 5"
```

**Why?** The `rcctl` utility (introduced in OpenBSD 5.8, now standard) provides a cleaner interface for daemon management. It handles ordering, flags, and status checking consistently. Direct file editing is error-prone.

#### 3. Privilege Escalation: sudo → doas

**Original isotop:**
```bash
# Some older systems used sudo
usermod -G wheel username
```

**isotop 7.8:**
```bash
# Modern doas configuration
echo "permit persist keepenv :wheel" >> /etc/doas.conf
```

**Why?** OpenBSD deprecated sudo in favor of `doas`, which is:
- Smaller and simpler codebase
- Fewer security vulnerabilities
- Default tool on modern OpenBSD
- More predictable behavior

#### 4. Session Management: Basic → Modern D-Bus Integration

**Original isotop:**
```bash
echo "exec mate-session" > ~/.xsession
```

**isotop 7.8:**
```bash
cat > ~/.xsession << 'EOF'
#!/bin/ksh
export LANG=en_US.UTF-8
eval "$(dbus-launch --sh-syntax)"
exec startxfce4
EOF
```

**Why?** Modern desktop applications require D-Bus for:
- Session management
- Hardware detection
- Privilege escalation
- System event notifications
- Sound system integration

#### 5. Display Manager: slim → xenodm

**Original isotop:**
```bash
echo "/usr/local/bin/slim -d" >> /etc/rc.local
# Or manual slim configuration
```

**isotop 7.8:**
```bash
rcctl enable xenodm
rcctl start xenodm
```

**Why?**
- `xenodm` is included in OpenBSD base system (no package needed)
- Lightweight and reliable
- Works perfectly with modern Xfce
- No external dependencies
- Better X11 session management

#### 6. Terminal Setup: SLiM → xenodm with .xsession

**Original isotop:**
```bash
# SLiM configuration in /etc/slim.conf
```

**isotop 7.8:**
```bash
# Uses standard X session management
# .xsession for xenodm (graphical)
# .xinitrc for startx (manual)
```

**Why?** Standard X session files are:
- POSIX-compliant
- Used by all display managers (xenodm, GDM, SDDM, etc.)
- Portable across different systems
- Easier to troubleshoot

### Migration Path for Existing Users

#### If you're running original isotop on OpenBSD 6.x

**Option 1: Fresh Install (Recommended)**
1. Install OpenBSD 7.8 from scratch
2. Run new isotop 7.8 scripts
3. Done!

**Option 2: In-Place Upgrade**

If you're upgrading from OpenBSD 6.x to 7.8 on existing hardware:

```bash
# Step 1: Backup your data
doas cp -r /home /home.backup
doas cp -r /etc /etc.backup

# Step 2: Upgrade OpenBSD base system
doas sysupgrade

# Step 3: Reboot with new kernel
doas reboot

# Step 4: Upgrade packages for new release
doas pkg_add -Uu

# Step 5: Clean up old isotop configurations
doas rm /etc/rc.conf.local  # Backup first if concerned
doas rm /etc/rc.local       # Backup first if concerned

# Step 6: Run new isotop scripts
doas sh isotop-7.8-root.sh
sh isotop-7.8-user.sh
```

#### If you're running original isotop on OpenBSD 7.x

Some improvements but mostly compatible:

```bash
# Minimal cleanup needed
# The new scripts are safe to run alongside old configs

# Optional: Remove old SLiM/SLiMd configurations
doas rcctl disable slim      # If you have it

# Run new scripts
doas sh isotop-7.8-root.sh
sh isotop-7.8-user.sh
```

### Configuration Migration Reference

#### Old → New File Locations and Methods

| Original | New | Notes |
|----------|-----|-------|
| `~/.profile` (PKG_PATH) | `/etc/installurl` | System-wide, managed by root |
| `/etc/rc.conf.local` (manual) | `rcctl enable/disable` | Automatic daemon management |
| `/etc/rc.local` (slim entry) | `rcctl enable xenodm` | Cleaner approach |
| `~/.xinitrc` (slim) | `~/.xsession` (xenodm) | Standard X session file |
| `sudo` access | `doas` access | Modern privilege escalation |
| `/etc/slim/slim.conf` | `/etc/X11/xenodm/` | Different display manager |

### Daemon Name Changes

Some daemons were renamed or reorganized:

| Original isotop | isotop 7.8 | Status |
|-----------------|-----------|--------|
| `dbus_daemon` | `messagebus` | Renamed (same daemon) |
| `avahi_daemon` | (optional) | Not required for basic desktop |
| `slim` | `xenodm` | Different display manager |
| (no audio daemon) | `sndiod` | Optional, for sound |
| (no session mgmt) | `consolekit` | New, handles sessions |
| (no polkit) | `polkitd` | New, handles privileges |

### Testing the Migration

After running new isotop 7.8 scripts:

```bash
# 1. Verify daemons are running
doas rcctl ls on

# Expected to see:
# messagebus
# polkitd
# consolekit
# apmd
# xenodm

# 2. Test privilege escalation
doas id    # Should work without password (cached)

# 3. Check package mirror
cat /etc/installurl

# 4. Test desktop
# Logout and log back in, or
startx

# 5. Check X session info
~/.local/bin/session-info
```

### Troubleshooting Migration Issues

#### Issue: "rcctl: service not found"

**Cause:** Daemon name mismatch

**Solution:**
```bash
# Check available services
doas rcctl ls all | grep -i bus    # Should show 'messagebus'
```

#### Issue: "permission denied" with new doas

**Cause:** doas.conf not properly configured

**Solution:**
```bash
doas cat /etc/doas.conf
# Should contain: permit persist keepenv :wheel

# Verify your user is in wheel group
groups
# Should include: wheel
```

#### Issue: X won't start after upgrade

**Cause:** Configuration conflict

**Solution:**
```bash
# Remove old configurations
rm -f ~/.xinitrc~
rm -f ~/.xsession~

# Regenerate with isotop user script
sh isotop-7.8-user.sh

# Test with startx
startx
```

#### Issue: Some services won't start

**Cause:** Missing packages from new release

**Solution:**
```bash
# Update all packages
doas pkg_add -Uu

# Install specific package
doas pkg_add messagebus  # or polkit, consolekit2, etc.

# Try again
doas rcctl start messagebus
```

### Rollback Procedures

If something goes wrong:

```bash
# Configuration backups are at:
ls -la /root/isotop-backup-*

# Restore specific file
doas cp /root/isotop-backup-DATE/doas.conf /etc/doas.conf

# Or restore entire backup
doas cp -r /root/isotop-backup-DATE/* /etc/

# Restart services
doas reboot
```

### Performance Differences

#### Original isotop
- Lighter: No unnecessary daemons
- But: Manual session management
- Issue: No privilege elevation in GUI apps

#### isotop 7.8
- Additional daemons: D-Bus, PolicyKit, ConsoleKit2
- Benefit: Better application integration
- Benefit: System tray functionality
- Memory: ~50-100MB additional
- CPU: Minimal impact

**Recommendation:** Keep modern daemons enabled. They provide essential functionality and overhead is negligible on systems with 2GB+ RAM.

### Performance Tuning if Needed

If you're on a memory-constrained system:

```bash
# Disable optional daemons
doas rcctl disable consolekit
doas rcctl disable polkitd

# Use lightweight window manager
doas pkg_add cwm
echo "exec cwm" > ~/.xinitrc
startx
```

**Note:** Some applications may not work without D-Bus/PolicyKit

### Recommended Post-Migration Steps

1. **Enable security patches:**
   ```bash
   doas syspatch        # Apply kernel patches
   doas pkg_add -Uu    # Update packages
   ```

2. **Optimize power management for your hardware:**
   ```bash
   # For laptops, current settings are good
   # For workstations, you might want:
   doas rcctl set apmd flags -H  # Performance mode
   ```

3. **Install additional applications as needed:**
   ```bash
   doas pkg_add firefox thunderbird gimp vlc
   ```

4. **Create local backups:**
   ```bash
   doas tar czf /root/openbsd-config-backup.tgz /etc
   cp -r ~/.config ~/config-backup
   ```

### FAQ: Original isotop Users

**Q: Do I need to completely reinstall?**
A: No, but a fresh install is cleaner. In-place upgrades work with the scripts provided.

**Q: Will my files be preserved?**
A: Yes, the migration scripts don't touch `/home` directory. All user data is safe.

**Q: Can I run both original and new isotop configs?**
A: Not recommended. The scripts are designed to replace, not coexist. Remove original configs first.

**Q: What if I prefer the original SLiM display manager?**
A: You can still use it: `doas pkg_add slim` and configure manually.

**Q: Is xenodm compatible with my custom .xinitrc?**
A: Xenodm uses `.xsession` by default, not `.xinitrc`. Rename your file if needed.

**Q: How do I revert to the original isotop?**
A: Install OpenBSD 6.8 (end-of-life, not recommended) or manually restore old configurations from backups.

### Summary of Benefits

isotop 7.8 provides:

✓ **Modern:** Uses current OpenBSD standards (rcctl, doas, installurl)
✓ **Stable:** Xenodm is more reliable than SLiM  
✓ **Secure:** Better privilege management with PolicyKit
✓ **Better Integration:** D-Bus enables system features
✓ **Maintainable:** Simpler daemon management
✓ **Documented:** Extensive inline comments
✓ **Tested:** Works with OpenBSD 7.8 stable

---

**Need Help?**

- Check `/root/isotop-backup-*/` for previous configs
- Review OpenBSD manual pages: `man rcctl`, `man doas`, `man xenodm`
- Visit: openbsdhandbook.com or daemonforums.org
- Check X session logs: `~/.local/share/xfce4/xfce4-session/xfce4-session.log`
