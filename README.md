# 🌐 OpenBSD KDE Desktop Suite

> **KDE Plasma 6 on OpenBSD 8.0 — automated, idempotent, reversible**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OpenBSD](https://img.shields.io/badge/OpenBSD-8.0%20%7C%207.9%20%7C%207.8-fuchsia.svg)](https://www.openbsd.org)
[![Shell](https://img.shields.io/badge/Shell-ksh-444444.svg)](https://man.openbsd.org/ksh)
[![CI](https://github.com/azazelpy/openbsd/actions/workflows/ci.yml/badge.svg)](https://github.com/azazelpy/openbsd/actions/workflows/ci.yml)

---

## Overview

Five small `ksh` scripts that turn a fresh OpenBSD 8.0 install into a KDE Plasma
desktop, one that verifies the result, and one that undoes it. Every script is
idempotent, every file it touches is backed up first, and every action can be
previewed with `--dry-run`.

| Script | Purpose | Run as | Time |
|--------|---------|--------|------|
| `setup-root.sh` | packages, mirror, doas, xenodm, touchpad | root | 10–20 min |
| `setup-user.sh` | session, shell env, KDE defaults, utilities | user | <1 min |
| `validate-install.sh` | read-only verification, `--json` mode | user | seconds |
| `rollback.sh` | restore the configs saved by `setup-root.sh` | root | seconds |
| `setup-vmware.sh` | VMware guest helper (`vmwh`), only inside a VM | root | 1 min |

Shared helpers live in `lib/common.sh`: logging, `--dry-run`, `--yes`,
timestamped backups, and the OpenBSD primitives (`pkg_info -e`,
`rcctl get … status`).

---

## Quick start

Prerequisites: OpenBSD 8.0 (or 7.9 / 7.8) with the X11 sets — `xbase80`,
`xshare80`, `xfont80`, `xserv80` on 8.0, `xbase78` … on 7.8 — network access,
and your user in the `wheel` group.

```sh
git clone https://github.com/azazelpy/openbsd.git
cd openbsd

doas ksh setup-root.sh        # 1. system: packages + daemons
ksh setup-user.sh             # 2. your account: session + shell
doas reboot                   # 3. reboot
```

After the reboot, log in at the xenodm prompt: the session defined in
`~/.xsession` starts Plasma.

> **xenodm has no session menu.** 2.0.0 told you to "click Session → KDE".
> The session is `~/.xsession`, which `setup-user.sh` writes. A session picker
> is a feature of SDDM/GDM, not of xenodm.

Verify at any time, as your normal user:

```sh
ksh validate-install.sh          # human readable
ksh validate-install.sh --json   # last line is machine readable
```

Undo the system configuration:

```sh
doas ksh rollback.sh --list      # what is available
doas ksh rollback.sh             # restore the newest backup
```

Every script supports `--dry-run`, `--yes`, `--verbose` and `--help`.

---

## What `setup-root.sh` does

1. **Pre-flight** — root check, OpenBSD release check, X11 sets present.
2. **Backup** — `/root/openbsd-kde-backup-<stamp>/` with a `MANIFEST.tsv`
   (backup path, target path, checksum) covering `doas.conf`, `sysctl.conf`,
   `installurl`, `rc.conf.local` and `wsconsctl.conf`, plus the installed
   package list. `rollback.sh` restores exactly what that manifest lists.
3. **Mirror** — keeps your existing `/etc/installurl`; writes
   `cdn.openbsd.org` only when the file is missing or empty, or whatever
   `--mirror URL` says.
4. **Packages** — `pkg_add -u`, then `kde-plasma` (the meta package that pulls
   `plasma-desktop`, `plasma-workspace`, `kwin`, `kscreenlocker`, `kf6-dolphin`
   and `konsole`), plus `dbus`, `polkit` and `consolekit2`; optionally `kate`,
   `firefox`, `thunderbird` and a small CLI tool set (`--no-apps`,
   `--no-tools`).
5. **doas** — adds `permit persist :wheel` **only** if no `:wheel` rule exists,
   then validates the file with `doas -C`. It never rewrites your rules.
6. **Daemons** — enables `xenodm` and `messagebus`. Nothing else is needed:
   `polkit` and `consolekit2` have no `rc.d` script on OpenBSD, D-Bus starts
   them on demand.
7. **Touchpad** — writes `mouse.tp.tapping=1` to `/etc/wsconsctl.conf` when a
   touchpad is detected (`--touchpad` / `--no-touchpad` to override).
8. **Verify** — packages, `startplasma-x11`, and whether both daemons are
   *enabled* (enabled ≠ running: a freshly configured box is not running them
   yet). Exits non-zero when a check fails.

### Verified package facts

Checked against the OpenBSD **8.0** package index (13 063 entries) and 7.8.
Each row was wrong or ambiguous in 2.0.0 and is the reason the suite exists in
this shape. The per-release detail is in [`COMPATIBILITY.md`](COMPATIBILITY.md).

| Fact | 2.0.0 | 2.1.1 (8.0) |
|------|-------|-------------|
| KDE meta package | `kde-plasma` ✅ (exists; pulls Plasma 6.4.5) | `kde-plasma-6.7.5p0` → Plasma 6.7.5 |
| D-Bus package | `messagebus` ❌ no such package | `dbus-1.16.2p1v0` (rc.d daemon: `messagebus`) |
| `tmux` | installed as a package ❌ | already in the base system |
| `vim` | `pkg_add vim` ❌ ambiguous flavours | 7.8: `vim--no_x11`; **8.0: plain `vim`** (default is console-only, only `-gtk3` is GUI) |
| Session binary | `startkde` ❌ removed in Plasma 6 | `/usr/local/bin/startplasma-x11` (still shipped in 6.7.5) |
| polkit / consolekit2 | `rcctl enable` ❌ no rc.d script | D-Bus activated, nothing to enable (still true in 8.0: `polkit-127p0`, `consolekit2-1.2.7p0`) |
| VMware Tools | `pkg_add vmware-tools` ❌ | `vmt(4)` in base + `vmwh-1.2v0` package |
| Audio | manual PulseAudio setup | `plasma-pa-6.7.5` pulls `pulseaudio-17.0p4` |

---

## What `setup-user.sh` does

| File | Content |
|------|---------|
| `~/.xsession` | `startplasma-x11`, wrapped in `ck-launch-session` when available; starts `vmwh` in a VMware guest |
| `~/.xinitrc` | loads `~/.xsession`, so `startx` and xenodm share one definition |
| `~/.profile` | `export ENV=$HOME/.kshrc`, `~/.local/bin` in `PATH`, editor and pager |
| `~/.kshrc` | four `ls` aliases, `mkcd`, `extract` — no aliases that shadow core tools |
| `~/.config/kdeglobals` | Breeze Dark look-and-feel, written only on first run |
| `~/.local/bin/system-info` | release, CPU, RAM, disk, KDE version, uptime |
| `~/.local/bin/lock-screen` | locks via `dbus-send` to `org.kde.screensaver` |
| `~/.local/bin/kde-restart` | restarts `plasmashell` only, never the session |
| `~/.local/bin/update-system` | `pkg_add -u` plus a `syspatch` reminder |

`export ENV=$HOME/.kshrc` is not cosmetic: ksh reads `~/.kshrc` only when `ENV`
points at it, so without that line the aliases never load. 2.0.0 wrote the
aliases and not the export.

`--hidpi 144` additionally writes `Xft.dpi` to `~/.Xresources`.

---

## Requirements and expectations

- **OpenBSD 8.0** is the current target and **7.8** the previous one; both are
  verified against their own package indexes. 7.9 passes the pre-flight check.
  Anything newer warns and continues.
- **~2 GB free on `/usr`** and roughly **600–800 MB of RAM** for a Plasma
  session. Measure on your own hardware: these are order-of-magnitude figures,
  not benchmarks.
- **xenodm is enabled at boot** by `setup-root.sh`. If you use another display
  manager, `doas rcctl disable xenodm` before rebooting.

---

## Troubleshooting

Short list — the full matrix is in [TROUBLESHOOTING.md](TROUBLESHOOTING.md):

```sh
doas rcctl get xenodm status        # enabled?  (rcctl check means "running")
doas rcctl enable xenodm
ls -l ~/.xsession                   # must be executable and exec startplasma-x11
tail -50 ~/.xsession-errors         # the session's own log
tail -50 /var/log/xenodm.log        # what xenodm saw
ksh validate-install.sh             # what is actually installed
```

---

## Documentation

| Document | Description |
|----------|-------------|
| `README.md` | this file |
| [INSTALL.md](INSTALL.md) | step-by-step install, manual fallback, uninstall |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | symptom → cause → fix |
| [KDE-CUSTOMIZATION.md](KDE-CUSTOMIZATION.md) | HiDPI, fonts, panels, default apps |
| [CHANGELOG.md](CHANGELOG.md) | version history, including every 2.1.0 fix |
| [SECURITY.md](SECURITY.md) | what runs as root, what it touches, how to review it |
| [AUDITORIA.md](AUDITORIA.md) | audit of 2.0.0: findings, evidence, status |

---

## Development

```sh
./tests/lint.sh              # mksh -n, shellcheck (ksh dialect), repo invariants
./tests/test-user-setup.sh   # runs setup-user.sh twice against a throw-away HOME
```

Both run in CI (`.github/workflows/ci.yml`) on every push and pull request. The
lint step also fails when one of the verified-broken patterns above reappears,
so those regressions cannot come back silently.

What CI does **not** cover: a full `setup-root.sh` run, which needs a real
OpenBSD machine (it refuses to run elsewhere by design). Package names are
checked against the published package index; the installer itself is not
exercised on a live box.

Contributions: fork, branch, keep `./tests/lint.sh` green, open a PR.

---

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgements

- The OpenBSD project, for the base system and the package infrastructure.
- The KDE community, for Plasma 6.
- [Isotop](https://github.com/sp00cky/isotop), for the original inspiration to
  automate an OpenBSD desktop.

## References

- OpenBSD FAQ — https://www.openbsd.org/faq/
- OpenBSD packages and ports — https://www.openbsd.org/faq/faq15.html
- KDE Plasma documentation — https://docs.kde.org/
