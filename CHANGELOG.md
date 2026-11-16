# CHANGELOG

All notable changes to this project. Format: [Keep a Changelog](https://keepachangelog.com/).
Versions follow [Semantic Versioning](https://semver.org/).

## [2.1.0] — 2026-11-16

Audit release. Fixes the findings in [AUDITORIA.md](AUDITORIA.md); 2.0.0 could
not complete a clean install on OpenBSD 7.8.

### Fixed — installation blockers

- `pkg_add messagebus` → the package is `dbus` (its rc.d daemon is
  `messagebus`). The old command aborted the run under `set -e`.
- `pkg_add tmux` → `tmux` is in the base system, there is no package. Removed.
- `pkg_add vim` → ambiguous between flavours. Now `pkg_add vim--no_x11`.
- `rcctl enable polkit` / `rcctl enable consolekit2` → neither package ships an
  rc.d script (both are D-Bus activated). Removed from the run.
- `~/.xsession` executed `startkde`, which Plasma 6 no longer ships. Now
  `/usr/local/bin/startplasma-x11`, wrapped in `ck-launch-session` when
  available.
- Verification used `rcctl check` ("is it running") to decide "is it enabled",
  reporting failures on a freshly configured box. Now `rcctl get <daemon>
  status`.

### Fixed — rollback and backups

- `rollback.sh` did not parse at all: `[[ ! "$x" =~ ^[Yy]$ ]]` is a ksh93
  feature that OpenBSD ksh does not implement. Rewritten with `case`.
- `rollback.sh` announced restoring `/etc/rc.conf.local` and `/etc/fstab`, and
  `setup-root.sh` never backed either of them up. Backups now include
  `rc.conf.local` and record everything in `MANIFEST.tsv` with checksums;
  rollback restores exactly that list.
- `backup_file` overwrote `<file>.bak` on every run, so the second run replaced
  the user's original with the generated file. Backups are now
  `<file>.orig.<timestamp>` and the first one wins.
- Rollback keeps the pre-rollback state as `<file>.pre-rollback.<timestamp>`.

### Fixed — configuration that silently did nothing

- `~/.kshrc` aliases were never read: ksh reads that file only when `ENV` points
  at it. `~/.profile` now exports `ENV=$HOME/.kshrc`.
- `/etc/sysctl.conf` received `kern.sbmax` and `kern.somaxkva`, which do not
  exist in OpenBSD's sysctl(2). The step is gone; the suite writes no sysctl
  tunables.
- `~/.wsconsctl.conf` is not read by anything: `wsconsctl(8)` documents
  `/etc/wsconsctl.conf`. Tap-to-click is now a system setting, applied by
  `setup-root.sh` only when a touchpad is detected.
- `mkdir -p ~/.config/dolphinrc` created a directory where Dolphin expects a
  file. Removed.
- `lock-screen` looked for a `kscreenlocker` binary that the package does not
  install; it always fell through to `xlock`. Now `dbus-send` to
  `org.kde.screensaver` with a fallback.
- Generated `~/.xinitrc` called `print_error`/`print_info`, which do not exist
  inside the generated file. The session script is now self-contained.
- doas: dropped `keepenv` from the generated rule, and validation now uses
  `doas -C /etc/doas.conf` (`doas -n true` as root validates nothing).

### Changed

- `setup-vmware.sh` rewritten: there is no `vmware-tools` package on 7.8;
  `vmt(4)` is in the base system and host mouse integration comes from the
  `vmwh` package. The invented `vmtoolsd`/`vmblock` services and the
  `20-vmwgfx.conf` Xorg file (wrong driver name, three pinned resolutions) are
  gone.
- `/etc/installurl` is preserved when it already points at a mirror; it is
  backed up and only written on request or when absent.
- All scripts gained `--dry-run`, `--yes`, `--verbose`, `--log` and `--help`,
  plus a shared library (`lib/common.sh`) instead of five copies of the same
  header.
- `pkg_add` is called with `-I` (non-interactive) and each install is checked
  first with `pkg_info -e`, so re-runs are quiet and idempotent.
- `validate-install.sh` is read-only, adds `--json`, checks the filesystem that
  actually holds the packages (`/usr`), and no longer suggests editing
  `/etc/rc.conf.local` by hand.
- Verified package/daemon facts documented in the README with the 2.0.0 error
  next to each fix.

### Fixed — found by the independent audit of 2.1.0

The 2.1.0 work was audited by Claude Code (Sonnet, effort medium) against its
own brief; the verdict was "apply with changes". These are the changes.

- **Blocker:** `setup-root.sh` never ran `rcctl enable messagebus`, while its
  verification demanded `messagebus` be enabled. A clean install therefore
  ended with exit 1. Added `configure_dbus()`.
- `write_file` now compares before writing: identical content is not rewritten
  (stable mtime) and the previous version is preserved as `.orig.<stamp>` only
  when it actually differs. Before, a manual edit to `~/.xsession` was silently
  overwritten on the next run while a useless `.orig` of generated content sat
  next to it.
- `append_block` matched its marker anywhere in the file, including commented
  lines: `/etc/wsconsctl.conf` with `#mouse.tp.tapping=1` counted as configured.
  Markers are now matched at the start of a non-comment line (awk, no regex).
- The backup manifest is typed (`FILE` / `ABSENT` / `SERVICE`), so `rollback.sh`
  also removes files the installer created and restores the previous
  enabled/disabled state of `messagebus` and `xenodm`. Untyped 2.1.0 manifests
  are still read.
- Failed `pkg_add` calls are now reported as a failed check instead of being
  counted and dropped; the verification used to look at `kde-plasma` only.
- `update-system` used `syspatch -l` (installed patches) and labelled the output
  "pending"; `-c` lists the available ones.
- `system-info` used `cmd | awk … || echo fallback`, so the fallback never ran
  and a missing `kde-plasma` printed an empty version.
- `--hidpi` rejects non-numeric values instead of interpolating them into
  `~/.Xresources`, and the "utility scripts executable" check no longer reports
  success when one of the four is missing.

### Added

- `lib/common.sh` — logging, backups, `pkg_installed`, `svc_enabled`,
  `append_block`, `write_file`.
- `tests/lint.sh` — `mksh -n`, shellcheck (ksh dialect), optional `shfmt`
  check, repository invariants, and a forbidden-pattern list that fails the
  build if any 2.0.0 bug comes back.
- `tests/test-user-setup.sh` — runs `setup-user.sh` twice against a throw-away
  `$HOME`, asserts idempotency (one `.orig` backup, no duplicated block) and
  that `--dry-run` writes nothing.
- `.github/workflows/ci.yml` — lint and integration test on every push and PR.
- `INSTALL.md`, `TROUBLESHOOTING.md`, `KDE-CUSTOMIZATION.md` — the README linked
  to all three in 2.0.0; none of them existed.
- `SECURITY.md` — what runs as root, what it touches, how to review it first.
- `AUDITORIA.md` — the audit of 2.0.0 with evidence per finding.

### Removed

- `kde-apps` from the documentation: no such package exists (the metas are
  `kde-plasma`, `kde-plasma-extras`, `kde-<category>`).
- The xenodm "Session → KDE Plasma" instructions: xenodm has no session menu.
- Marketing claims that could not be backed by a test ("tested on real OpenBSD
  systems", "syntax-validated"): replaced by what CI actually runs.

## [2.0.0] — 2026-03-17

- Rewritten from Xfce to KDE Plasma.
- Added `validate-install.sh` and `rollback.sh`.
- Added VMware guest script.
- Known at the time: the install could not complete on 7.8 (see 2.1.0).

## [1.0.0] — 2026-02

- Initial Xfce-based automation: `.xsession`, `.xinitrc`, shell environment.
