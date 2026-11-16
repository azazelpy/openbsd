# KDE-CUSTOMIZATION.md

Plasma is configured through files in `~/.config`, and every setting in the GUI
is a line you can also write from the shell with `kwriteconfig6`. The suite
writes only the minimum (Breeze Dark look-and-feel); everything below is
optional.

---

## Scaling and HiDPI

Three layers, in the order that matters:

1. **Xft.dpi** — GTK and X11 clients. Written by `ksh setup-user.sh --hidpi 192`
   (or edit `~/.Xresources` and reload with `xrdb -merge ~/.Xresources`).
2. **Plasma global scale** — Qt applications and the shell itself:
   *System Settings → Display & Monitor → Global scale* (100 / 125 / 150 %).
3. **Per-application overrides** — for the stubborn ones:
   ```sh
   kwriteconfig6 --file kdeglobals --group General --key XftHintStyle hintslight
   QT_SCALE_FACTOR=1.5 konsole        # one-off test
   ```

Do not mix a 200 % global scale with a 96 dpi `Xft.dpi`: pick one and adjust the
other to match, or fonts and icons will disagree.

---

## Look and feel

```sh
# list installed global themes
kwriteconfig6 --help >/dev/null && ls /usr/local/share/plasma/look-and-feel

# switch to Breeze Dark (the suite's default)
kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage \
    org.kde.breezedark.desktop
kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
```

Apply without logging out: *System Settings → Colors & Themes → Global Theme →
Apply*. A full session restart is only needed for window decorations.

---

## Panels and widgets

Panel layout lives in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`. It is
a generated file: editing it by hand is possible but fragile, and Plasma rewrites
it on exit.

To keep a layout across machines, copy the file while **Plasma is not running**
(for example from a TTY), or build the layout with a Plasma script:

```sh
# add a second panel at the top, 32px tall, with a task manager
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
  var p = new Panel;
  p.location = "top"; p.height = 32;
  p.addWidget("org.kde.plasma.taskmanager");
'
```

`qdbus6` comes with `qt6-qttools` if it is not already present.

---

## Default applications

```sh
xdg-settings set default-web-browser firefox.desktop
xdg-mime default org.kde.kate.desktop text/plain
xdg-mime query default text/plain        # verify
```

KDE also keeps its own associations in `~/.config/mimeapps.list`; the `xdg-*`
tools write to the same file.

---

## Keyboard shortcuts

*System Settings → Shortcuts* is the easy path. For scripted setups:

```sh
# bind Meta+Return to Konsole
kwriteconfig6 --file kglobalshortcutsrc --group "org.kde.konsole.desktop" \
    --key "_launch" "Meta+Return,none,Konsole"
```

Shortcut changes need `qdbus6 org.kde.kglobalaccel /kglobalaccel \
org.kde.KGlobalAccel.reloadConfig` or a re-login.

---

## Effects and compositing

KWin effects are cheap on modern hardware and expensive on old GPUs:

```sh
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file kwinrc --group Compositing --key Enabled true
qdbus6 org.kde.KWin /KWin reconfigure
```

If a virtual machine feels sluggish, turn off `blur`, `contrast` and
`slidingpopups` before touching anything else. `kcmshell6 kcm_kwincompositing`
is the GUI equivalent.

---

## Terminal (Konsole)

```sh
# a plain, readable profile you can copy between machines
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile \
    Suite.profile
```

Put the profile in `~/.local/share/konsole/Suite.profile`:

```ini
[Appearance]
ColorScheme=Breeze
Font=Hack,11,-1,5,50,0,0,0,0,0

[General]
DefiniteScrollback=1
HistorySize=10000
```

`fc-list | grep -i hack` shows whether the font is installed; `doas pkg_add
hack-fonts` if not.

---

## Where the suite stops

Everything in this file is user preference and outside `validate-install.sh`'s
scope on purpose: it checks that the desktop starts and that the daemons it
needs are enabled, not that the panel is where you like it.
