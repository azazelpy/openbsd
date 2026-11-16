# TROUBLESHOOTING.md

Symptom → cause → fix. Start with the two commands that answer most questions:

```sh
ksh validate-install.sh                          # what is installed and enabled
doas rcctl get xenodm status; echo "exit=$?"      # 0 = enabled
```

`rcctl check xenodm` tests whether xenodm is **running**; `rcctl get xenodm
status` tests whether it is **enabled**. 2.0.0's verification used the first
when it meant the second, which is why a freshly configured box reported
failures.

---

## Boot and display manager

### The machine boots straight to a text login

```sh
doas rcctl get xenodm status      # exit 0 = enabled
doas rcctl enable xenodm          # enable if needed
doas rcctl start xenodm
```

If `rcctl enable` says `xenodm: unknown daemon`, the X11 sets are not installed.

### xenodm starts, then the screen goes black and returns to the login prompt

The session died. Look at, in this order:

```sh
tail -50 ~/.xsession-errors
tail -50 /var/log/xenodm.log
```

Typical causes:

| Message | Cause | Fix |
|---|---|---|
| `startkde: not found` | `~/.xsession` from 2.0.0 — Plasma 6 has no `startkde` | `ksh setup-user.sh` (writes `startplasma-x11`) |
| `startplasma-x11: not found` | `kde-plasma` not installed | `doas pkg_add kde-plasma` |
| permission denied on `~/.xsession` | wrong mode | `chmod 700 ~/.xsession` |
| `cannot open display` / X auth | stale `~/.Xauthority` | `rm ~/.Xauthority`, log in again |

### `startx` works but xenodm does not

`startx` uses `~/.xinitrc`, xenodm uses `~/.xsession`. Both are written by
`setup-user.sh`, and `~/.xinitrc` simply loads `~/.xsession`, so the two paths
cannot drift.

---

## Packages

### `pkg_add: no such package: messagebus`

The package is called `dbus`; `messagebus` is the name of its `rc.d` daemon.

```sh
doas pkg_add dbus
doas rcctl enable messagebus
```

### `pkg_add: ambiguous package name: vim`

`vim` is built in flavours:

```sh
doas pkg_add vim--no_x11     # terminal editor
doas pkg_add vim--gtk3       # optional GUI
```

### `pkg_add: no such package: tmux`

`tmux` is part of the base system: run `tmux`, do not install it.

### `pkg_add: no such package: vmware-tools`

There is no VMware Tools package on OpenBSD 7.8. `vmt(4)` is in the kernel, and
host mouse integration comes from `vmwh`:

```sh
doas ksh setup-vmware.sh
grep -c vmwh ~/.xsession      # the session must launch it
```

### Signature or checksum errors from `pkg_add`

```sh
doas pkg_check            # repairs the package database
cat /etc/installurl       # must match your release (7.8, not -current)
```

---

## Permissions and doas

### `doas` says `doas: Operation not permitted`

Your user is not in `wheel`, or the rule is missing:

```sh
id -Gn | tr ' ' '\n' | grep -x wheel
doas -C /etc/doas.conf
```

Adding the group takes effect on the next login: log out and back in.

### `doas -C /etc/doas.conf` reports a syntax error

You edited the file while `setup-root.sh` was appending. Restore the copy:

```sh
doas ksh rollback.sh --list
doas ksh rollback.sh
```

### KDE asks for a password for everything, or mount/suspend do nothing

`polkit` and `consolekit2` drive those prompts. They are D-Bus activated, so
there is nothing to `rcctl enable`; they just have to be installed, and the
session has to be registered with ConsoleKit2:

```sh
pkg_info -e 'polkit-*' 'consolekit2-*'
grep -c ck-launch-session ~/.xsession     # ≥1 when consolekit2 is installed
```

If the count is 0, re-run `ksh setup-user.sh`.

---

## Sound

OpenBSD audio is sndio (`sndiod`, `mixerctl`, `sndioctl`). Plasma's volume applet
uses PulseAudio, which on OpenBSD plays through sndio.

```sh
doas pkg_add pulseaudio plasma-pa
# start a session daemon once, then use the applet
pulseaudio --start --exit-idle-time=-1
mixerctl outputs.master        # the hardware side
```

Two corrections to the 2.0.0 instructions:

- `doas usermod -G audio $(whoami)` **fails on OpenBSD**: there is no `audio`
  group. Audio access is governed by sndio device permissions (`/dev/audio*`).
- Rebooting is not required; the PulseAudio daemon is per session.

---

## Touchpad, keyboard, screen

### Tap-to-click does not work

`wsconsctl` writes to `/dev/wsmouse`, which is owned by `root:wscons`; a normal
user is not in that group, so tap-to-click is a system setting:

```sh
cat /etc/wsconsctl.conf          # expect: mouse.tp.tapping=1
doas ksh setup-root.sh --touchpad
doas reboot
```

There is no `~/.wsconsctl.conf`: `wsconsctl(8)` documents `/etc/wsconsctl.conf`
only. 2.0.0 wrote a per-user file that nothing ever read.

### Everything is tiny on a HiDPI panel

```sh
ksh setup-user.sh --hidpi 192     # writes Xft.dpi to ~/.Xresources
```

Then, inside Plasma: *System Settings → Display & Monitor → Global scale*.
Plasma scales Qt applications itself; `Xft.dpi` covers GTK/X11 clients.

### Keyboard layout is wrong at the login screen

xenodm uses the wscons console encoding:

```sh
doas wsconsctl keyboard.encoding=es
echo 'keyboard.encoding=es' | doas tee -a /etc/wsconsctl.conf
```

---

## Rollback

### `rollback.sh` restores nothing (2.0.0 backups)

2.0.0 wrote no manifest and backed up only three files. 2.1.0 restores from
`MANIFEST.tsv` and falls back to the old layout for old backups:

```sh
doas ksh rollback.sh --list
ls /root/openbsd-kde-backup-*/MANIFEST.tsv
```

### I want my original `~/.profile` back

Every user file is backed up as `<file>.orig.<timestamp>`:

```sh
ls ~/.profile.orig.*
cp -p ~/.profile.orig.20261116-103000 ~/.profile
```

`rollback.sh` does not touch user files; that is deliberate.

---

## VMware guests

| Symptom | Fix |
|---|---|
| Mouse jumps / grabs | `doas ksh setup-vmware.sh`, then log out and in (`vmwh` runs inside X) |
| Wrong resolution, cannot change | remove any `/etc/X11/xorg.conf*` you added: OpenBSD autoconfigures, and a pinned `Modes` line blocks randr |
| Host clock drifts | `dmesg` should show `vmt0`; that driver syncs from the host clock |
| Copy-paste host → guest | X selections only; install `xclip` and use `Shift+Insert` in xterm |
