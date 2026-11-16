# COMPATIBILITY — OpenBSD releases

Every row below was read from the official package index, the package contents
(`+CONTENTS` inside the `.tgz`), or the release's own man pages. Nothing is
assumed from memory. If a row is wrong for your release, the suite will fail
loudly at the step that uses it (the pre-flight refuses unknown releases and
warns on untested ones).

| | **8.0** (current, Oct 2026) | **7.9** | **7.8** (previous target) |
|---|---|---|---|
| Status | **verified** — target | **verified** | **verified** |
| Package index size | 13 063 entries | 13 047 entries | 12 651 entries |
| X11 sets | `xbase80 xshare80 xfont80 xserv80` | `xbase79 xshare79 xfont79 xserv79` | `xbase78 xshare78 xfont78 xserv78` |
| KDE meta | `kde-plasma-6.7.5p0` (47 deps) | `kde-plasma-6.6.4` | `kde-plasma-6.4.5` |
| Plasma workspace | `plasma-workspace-6.7.5` | `plasma-workspace-6.6.4` | `plasma-workspace-6.4.5` |
| Session binary | `bin/startplasma-x11` ✅ | `bin/startplasma-x11` ✅ | `bin/startplasma-x11` ✅ |
| D-Bus package | `dbus-1.16.2p1v0` + `@rcscript /etc/rc.d/messagebus` | `dbus-1.16.2p1v0` (same build) | same ✅ |
| `dbus-send` / `dbus-launch` | ✅ (used by `lock-screen`) | same build | ✅ |
| `polkit` | `polkit-127p0`, **no rc.d** | `polkit-127p0`, **no rc.d** | `polkit-126p2`, **no rc.d** |
| `consolekit2` | `consolekit2-1.2.7p0`, **no rc.d** | `consolekit2-1.2.6p6`, **no rc.d** | `consolekit2-1.2.6p4`, **no rc.d** |
| `kscreenlocker` | `6.7.5` (no CLI binary; lock via D-Bus) | `6.6.4` | `6.4.5` |
| `kf6-kconfig` | `6.30.0` → `kreadconfig6`, `kwriteconfig6` | present | `6.18.0` → same |
| VMware helper | `vmwh-1.2v0` ✅; no `vmware-tools`/`open-vm-tools` | `vmwh-1.2v0` | `vmwh` |
| `tmux` | in base, also has a package (not installed) | in base | in base |
| `vim` | default `vim-9.2.1125p0` is **console-only**; no `-no_x11` flavour | default `vim-9.2.357` **console-only**; no `-no_x11` flavour | `vim--no_x11` flavour **does** exist |
| Audio | `plasma-pa-6.7.5` → `pulseaudio-17.0p4` (arrives with `kde-plasma`) | same | same |
| `syspatch -c` | lists **available** patches | same | same |
| `rcctl get <daemon> status` | 0 = enabled | same | same |
| `mouse.tp.tapping` | documented in `wsmouse(4)` | same | same |

The `vim` row is the one release-specific branch in the code: `setup-root.sh`
installs `vim--no_x11` on 7.8 and plain `vim` everywhere else, because the
default build stopped linking X11 in 7.9.

## What "verified" does and does not mean

**It means:** every package name, daemon name, binary path and flag the scripts
use exists, or does not exist, exactly as documented, on that release.

**It does not mean:** that a full install has been run on that release's
hardware. `setup-root.sh` refuses to run outside OpenBSD on purpose, so the
end-to-end run is the one step no CI here can do. Run `doas ksh setup-root.sh
--dry-run` first and read the plan.

## Checking a release newer than this table

Three commands, no root:

```sh
# 1. package index for your release (replace 8.0 with yours)
ftp -o /tmp/idx.txt https://cdn.openbsd.org/pub/OpenBSD/8.0/packages/amd64/index.txt
grep -oE 'kde-plasma-[0-9][^ ]*\.tgz' /tmp/idx.txt

# 2. what the session binary is called in this release
ftp -o - https://cdn.openbsd.org/pub/OpenBSD/8.0/packages/amd64/plasma-workspace-*.tgz |
	tar -xzOf - +CONTENTS | grep -E '@bin bin/startplasma'

# 3. does anything new need enabling at boot?
ftp -o - https://cdn.openbsd.org/pub/OpenBSD/8.0/packages/amd64/dbus-*.tgz |
	tar -xzOf - +CONTENTS | grep '@rcscript'
```

If `startplasma-x11` disappears in a future release (Plasma is moving to
Wayland), `setup-user.sh` is the only file that has to change: `~/.xsession`
execs whatever this command prints. Note that xenodm is X11-only, so a
Wayland-only Plasma would need a different display manager as well.
