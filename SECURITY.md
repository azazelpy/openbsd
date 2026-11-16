# Security notes

These scripts configure a system as root. That is the whole trust model, so this
file says exactly what they touch and how to review it before running.

## What runs as root

| Script | Privileges | Touches |
|---|---|---|
| `setup-root.sh` | root (`doas`) | `/etc/installurl`, `/etc/doas.conf`, `/etc/wsconsctl.conf`, `rc.conf.local` via `rcctl`, package database |
| `setup-vmware.sh` | root (`doas`) | package database (`vmwh`) only |
| `rollback.sh` | root (`doas`) | restores files listed in the backup manifest |
| `setup-user.sh` | your user | `$HOME` only — refuses to run as root |
| `validate-install.sh` | your user | reads files; changes nothing |

## Rules the scripts follow

- **Backup before write.** Nothing in `/etc` is modified before a copy exists in
  `/root/openbsd-kde-backup-<stamp>/`, with a sha256 in `MANIFEST.tsv`. That
  manifest is typed: `FILE` (restore), `ABSENT` (the installer created it —
  rollback removes it) and `SERVICE` (previous enabled/disabled state).
- **A user file is only copied when it actually changes.** `write_file`
  compares first: identical content is not rewritten, and a modified file is
  preserved as `<file>.orig.<timestamp>` before being regenerated.
- **Append, do not rewrite.** `doas.conf`, `wsconsctl.conf`, `~/.profile` and
  `~/.kshrc` receive an appended block guarded by a marker; existing lines are
  never removed.
- **No `curl | sh`.** The only network paths are `pkg_add` (signature-checked by
  `signify` against `/etc/signify/*-pkg.pub`) and `git clone` of this repo.
- **No secrets handled.** No script reads, writes or prints a password, token or
  key. There is nothing to leak and no credential to rotate.
- **`--dry-run` is honest.** Every write goes through one of two helpers
  (`write_file`, `append_block`) that print instead of writing under
  `--dry-run`; `pkg_add` maps to `pkg_add -n`.
- **`doas` rule added is the minimum.** `permit persist :wheel` — no `nopass`,
  no `keepenv`, no per-command rules. If a `:wheel` rule already exists, nothing
  is added.
- **Verification is not a self-report.** `validate-install.sh` re-reads the
  system (`pkg_info -e`, `rcctl get … status`, `[ -x … ]`); it does not trust
  the installer's log.

## What the scripts deliberately do not do

- They do not disable or reconfigure `pf`, `sshd`, or any network service.
- They do not enable `nopass` in `doas.conf`.
- They do not install software from outside the OpenBSD package repository.
- They do not change file modes of existing files except the ones they create
  (`~/.xsession`, `~/.xinitrc`, `~/.local/bin/*` — all `0700`/`0755`).

## Reviewing before running

```sh
ksh -n setup-root.sh                # parses?
doas ksh setup-root.sh --dry-run    # what would it do?
```

The dry run prints every path it would write and every `pkg_add` it would call,
in order. If the list contains something you did not expect, stop there.

## Reporting

Open an issue with the command you ran and the output. Do not paste credentials
or the contents of `/etc/doas.conf` if it contains site-specific rules.
