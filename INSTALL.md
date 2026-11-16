# INSTALL.md — step by step

Target: OpenBSD 7.8, KDE Plasma 6.4, xenodm as display manager.
Time: 10–20 minutes, most of it `pkg_add` downloading ~1.5 GB.

---

## 0. Prerequisites

| Requirement | How to check | If missing |
|---|---|---|
| OpenBSD 7.8 | `uname -r` | other releases work but are untested |
| X11 sets | `ls /usr/X11R6/bin/X` | re-run the installer and select `xbase78 xshare78 xfont78 xserv78` |
| Package mirror | `cat /etc/installurl` | `setup-root.sh` writes the default |
| Network | `ftp -o /dev/null https://cdn.openbsd.org/` | fix DNS/route first |
| `wheel` membership | `id -Gn` | `doas usermod -G wheel "$USER"`, then log out and in |
| Free space on `/usr` | `df -h /usr` | 2 GB minimum |
| RAM | `sysctl -n hw.physmem` | ~1 GB minimum, 2 GB comfortable |

`doas` must already work before `setup-root.sh` can help you — it needs root to
configure root. On a stock install the `wheel` rule is usually already present.

---

## 1. System configuration

```sh
doas ksh setup-root.sh --dry-run     # optional: see every action first
doas ksh setup-root.sh
```

What it changes, in order:

1. `/root/openbsd-kde-backup-<stamp>/` — copies of every file it may touch plus
   `MANIFEST.tsv` (backup path, target path, sha256) and the package list.
2. `/etc/installurl` — left alone if it already has a mirror.
3. `pkg_add -u`, then `kde-plasma dbus polkit consolekit2` (+ `kate firefox
   thunderbird git vim--no_x11 nano htop curl wget` unless `--no-apps` /
   `--no-tools`).
4. `/etc/doas.conf` — appends `permit persist :wheel` only when no `:wheel`
   rule exists. Validates with `doas -C`.
5. `rcctl enable xenodm messagebus`.
6. `/etc/wsconsctl.conf` — `mouse.tp.tapping=1` when a touchpad is detected.
7. Verification: packages present, `startplasma-x11` present, both daemons
   **enabled**, `doas.conf` parses. Non-zero exit on failure.

Useful flags:

```sh
doas ksh setup-root.sh --mirror https://ftp.eu.openbsd.org/pub/OpenBSD
doas ksh setup-root.sh --no-apps --no-tools
doas ksh setup-root.sh --no-touchpad
doas ksh setup-root.sh --verbose --log /tmp/setup.log
```

---

## 2. User configuration

As yourself, not root:

```sh
ksh setup-user.sh
ksh setup-user.sh --hidpi 144     # laptop / 4K panel
```

It writes `~/.xsession`, `~/.xinitrc`, `~/.profile`, `~/.kshrc`,
`~/.config/kdeglobals` and four scripts in `~/.local/bin/`. Existing files are
copied to `<file>.orig.<timestamp>` first — the first backup wins, so running
the script again never replaces your original with a generated file.

---

## 3. Reboot and log in

```sh
doas reboot
```

At the xenodm prompt enter your username and password. There is **no session
menu**: xenodm runs `~/.xsession`, which starts Plasma. If you want to pick a
session at login, that requires SDDM or GDM, which this suite does not install.

Alternative without a reboot: `startx` (uses `~/.xinitrc`, which loads
`~/.xsession`).

---

## 4. Verify

```sh
ksh validate-install.sh
```

Exit status `0` means no failures. Warnings are optional-component gaps.
`--json` prints `{"passed":N,"warnings":N,"failed":N}` as the last line, for
scripting.

---

## 5. Uninstall

Two levels:

```sh
# a) configuration only: restore what setup-root.sh saved
doas ksh rollback.sh --list
doas ksh rollback.sh           # restores doas.conf, sysctl.conf, installurl,
                               # rc.conf.local, wsconsctl.conf from the manifest

# b) configuration + packages
doas pkg_delete kde-plasma dbus polkit consolekit2
doas rcctl disable xenodm
doas reboot
```

`rollback.sh` restores files and leaves packages installed on purpose: removing
a desktop is a separate decision, and it prints the `pkg_delete` line to run.

User files are not removed by either path. To revert them by hand:

```sh
# the four utilities and the session files
rm -f ~/.local/bin/system-info ~/.local/bin/lock-screen \
      ~/.local/bin/kde-restart ~/.local/bin/update-system
rm -f ~/.xsession ~/.xinitrc

# the suite blocks inside ~/.profile and ~/.kshrc are delimited:
#   # >>> openbsd-kde-suite … # <<< openbsd-kde-suite
# delete those lines (and any ~/.config/kdeglobals you want to reset).
```

---

## Manual fallback

If you prefer to do it by hand, these are the equivalent commands. They are
what the scripts run, minus the guards, backups and verification.

```sh
# packages
doas pkg_add -u
doas pkg_add kde-plasma dbus polkit consolekit2

# daemons: only these two exist on OpenBSD
doas rcctl enable xenodm messagebus
# polkit and consolekit2 are D-Bus activated - nothing to enable

# doas (only if /etc/doas.conf has no :wheel rule)
echo 'permit persist :wheel' | doas tee -a /etc/doas.conf
doas -C /etc/doas.conf

# session
cat > ~/.xsession <<'EOF'
#!/bin/ksh
export LANG=${LANG:-en_US.UTF-8}
exec /usr/local/bin/startplasma-x11
EOF
chmod 700 ~/.xsession

# ksh only reads ~/.kshrc when ENV points at it
echo 'export ENV=$HOME/.kshrc' >> ~/.profile
```

---

## Notes on specific environments

**VMware / VirtualBox guests.** `vmt(4)` ships in the base system and handles
host shutdown/reboot requests and clock sync. For host mouse integration install
the `vmwh` package (`doas ksh setup-vmware.sh`), which `setup-user.sh` then
starts from `~/.xsession`. No Xorg configuration file is needed; in fact a
hard-coded `xorg.conf` is the most common cause of "wrong resolution" after a
reboot. Clipboard between host and guest is limited: `vmwh` + `xclip` cover X
selections, drag-and-drop does not exist.

**Other display managers.** SDDM is packaged, but this suite is built around
xenodm and `~/.xsession`. If you switch, run `doas rcctl disable xenodm` and let
that display manager read `/usr/local/share/xsessions/plasmax11.desktop`.
