# Auditoría de `azazelpy/openbsd` — 2.0.0 → 2.1.0

**Fecha:** 2026-11-16
**Objeto:** `azazelpy/openbsd` @ `748cd1d` («Security Audit Complete + Validation & Rollback Scripts»)
**Alcance:** los 5 scripts ksh, README y LICENSE; corrección y reescritura.
**Veredicto:** el proyecto no podía completar una instalación en OpenBSD 7.8 ni
arrancar una sesión Plasma 6, y su mecanismo de rollback no llegaba a
interpretarse. Se corrigió todo lo verificable sin una máquina OpenBSD; queda
una prueba de instalación real pendiente (§5).

---

## 1. Método (qué se verificó y contra qué)

| Fuente | Uso |
|---|---|
| Índice de paquetes 7.8 (`ftp.openbsd.org/pub/OpenBSD/7.8/packages/amd64/index.txt`, 12 651 entradas) | existencia y nombre exacto de cada paquete |
| `+CONTENTS` de `dbus`, `polkit`, `consolekit2`, `vmwh`, `kscreenlocker`, `plasma-workspace`, `plasma-desktop`, `kde-plasma` | qué binarios, rc.d scripts y servicios D-Bus instala cada paquete |
| `man.openbsd.org`: `rcctl(8)`, `ksh(1)`, `wsconsctl(8)`, `usermod(8)`, `xenodm(1)`, `pkg_add(1)`, `sysctl(2)` | semántica de `rcctl check` vs `get`, lectura de `ENV`, campos de `wsconsctl`, `-G` vs `-S`, ausencia de selector de sesión, `-n`/`-I`, sysctls existentes |
| `bin/ksh` de openbsd/src (`main.c:104`) | `local=typeset` (por eso `local` sí funciona en ksh de OpenBSD, y no en ksh93) |
| Ejecución local | `mksh -n`, `shellcheck -s ksh`, `shfmt -ln mksh`, y `tests/test-user-setup.sh` (2 corridas reales sobre un `$HOME` temporal) |

Todo hallazgo de abajo tiene una comprobación reproducible; no hay ninguno
basado en leer el README.

---

## 2. Marcador

| Severidad | Cantidad | Efecto |
|---|---|---|
| Crítico (impide instalar o arrancar) | 7 | la suite no funciona en 7.8 |
| Alto (función silenciosamente inútil o pérdida de datos) | 11 | backups, alias, touchpad, rollback |
| Medio (higiene, documentación, verificabilidad) | 5 | deriva docs↔código, sin CI |

---

## 3. Hallazgos críticos

### C1 — `pkg_add messagebus`: el paquete no existe

`setup-root.sh:151` ejecutaba `pkg_add messagebus polkit consolekit2`.
El paquete se llama **`dbus`**; `messagebus` es el nombre de su script rc.d
(`@rcscript /etc/rc.d/messagebus` en el `+CONTENTS` de `dbus-1.16.2p1v0`).
Con `set -e`, ese fallo **abortaba la instalación** antes de KDE.

**Corregido:** se instala `dbus` y se habilita `messagebus` con `rcctl`.

### C2 y C3 — `tmux` y `vim` en la lista de paquetes

- `setup-root.sh:162`: `pkg_add git vim nano htop tmux curl wget`.
- `tmux` **está en la base** de OpenBSD: no hay paquete (0 coincidencias en el
  índice de 7.8). `pkg_add tmux` falla.
- `vim` existe solo por *flavours* (`vim-9.1.1706-gtk3-lua`, `…-no_x11`, etc.):
  `pkg_add vim` es ambiguo y `pkg_add(1)` lo documenta como ejemplo de ambigüedad.

**Corregido:** `tmux` fuera de la lista; `vim--no_x11` como spec de instalación.

### C4 — La sesión ejecuta `startkde`, que no existe en Plasma 6

`setup-user.sh:126` y `:153` generaban `exec startkde`.
`plasma-workspace-6.4.5` instala `bin/startplasma-wayland` y
`bin/startplasma-x11` — **no hay `startkde`**. Resultado: la sesión muere y
xenodm vuelve al login (el usuario ve un parpadeo de pantalla negra).

**Corregido:** `exec ck-launch-session /usr/local/bin/startplasma-x11`
(con fallback a `startkde` solo si ese binario existiera).

### C5 — `rollback.sh` no se puede interpretar

`rollback.sh:208`: `if [[ ! "$response" =~ ^[Yy]$ ]]`.
`=~` es una extensión de ksh93; el ksh de OpenBSD (pdksh 5.2.14) no la tiene —
`man ksh` no la documenta en ninguna parte. Comprobación directa:

```
$ mksh -n rollback.sh
rollback.sh[208]: syntax error: unexpected operator/operand '=~'
```

El único mecanismo de deshacer era, por tanto, código muerto: fallaba al
parsear, antes de ejecutar una sola línea.

**Corregido:** `case "$response" in [yY]|[yY][eE][sS])`.

### C6 — `rcctl enable polkit` y `rcctl enable consolekit2` sobre daemons inexistentes

`setup-root.sh:247-252`. Ni `polkit-126p2` ni `consolekit2-1.2.6p4` instalan
script rc.d: se activan por D-Bus (`share/dbus-1/system-services/org.freedesktop.PolicyKit1.service`).
`rcctl` devuelve 2 («non-existent daemon») y `set -e` cortaba el script.

**Corregido:** se eliminan ambas llamadas; solo se habilitan `messagebus` y
`xenodm`, que son los dos servicios que existen.

### C7 — La verificación confunde «habilitado» con «corriendo»

`setup-root.sh:276-291` y `setup-vmware.sh:219-234` usaban `rcctl check`.
`rcctl(8)`: *«check — Check if daemon is running»*; para saber si está
habilitado hay que usar `rcctl get <daemon> status` (exit 0 = habilitado).
En una máquina recién configurada el daemon todavía no corre, así que la
verificación reportaba **fallos falsos** justo después de una instalación
correcta.

**Corregido:** `svc_enabled()` usa `rcctl get … status`; `svc_running()` usa
`rcctl check` solo cuando la pregunta es realmente «¿está corriendo?».

---

## 4. Hallazgos altos

| # | Hallazgo | Evidencia | Corrección |
|---|---|---|---|
| A1 | Los alias de `~/.kshrc` nunca se cargaban | `ksh(1)`: un shell interactivo lee `$ENV`; 2.0.0 escribía el archivo sin exportar `ENV` | `~/.profile` exporta `ENV=$HOME/.kshrc` |
| A2 | Los backups se destruían al re-ejecutar | `setup-user.sh:86`: `cp "$file" "${file}.bak"` — la segunda corrida copiaba el archivo ya generado sobre el original | `<file>.orig.<stamp>`, gana el primero |
| A3 | `rollback.sh` «restauraba» archivos que nunca se respaldaron | Restauraba `rc.conf.local` y `fstab`; `create_backup()` solo copiaba `doas.conf`, `sysctl.conf`, `Xsetup_0` | `MANIFEST.tsv` con rutas y sha256; se respalda `rc.conf.local` e `installurl` |
| A4 | Sysctls inexistentes etiquetados «KDE optimizations» | `kern.sbmax` y `kern.somaxkva` no aparecen en `sysctl(2)` de OpenBSD | se elimina el paso; no se escriben tunables |
| A5 | El touchpad nunca se configuró | 2.0.0 escribía `~/.wsconsctl.conf`; `wsconsctl(8)` solo documenta `/etc/wsconsctl.conf` | se escribe el archivo del sistema, y solo si hay touchpad |
| A6 | `mkdir -p ~/.config/dolphinrc` | `setup-user.sh:303`: crea un **directorio** donde Dolphin espera un archivo | eliminado |
| A7 | `lock-screen` nunca bloqueaba con KDE | `kscreenlocker-6.4.5` no instala binario `kscreenlocker` (solo `libexec/kscreenlocker_greet`): el `command -v` siempre fallaba | `dbus-send` a `org.kde.screensaver` con fallback a `xlock` |
| A8 | Los archivos generados llamaban funciones inexistentes | El heredoc de `~/.xinitrc` usaba `print_error`/`print_info`, definidas en el instalador, no en el archivo generado | sesión autocontenida |
| A9 | `keepenv` y validación de doas inútiles | `permit persist keepenv :wheel` pasa el entorno del usuario a root sin necesidad; `doas -n true` como root no consulta la política | `permit persist :wheel`; validación con `doas -C` |
| A10 | `installurl` se sobrescribía sin backup | `setup-root.sh:116` escribía `ftp.openbsd.org` siempre | se preserva el mirror existente; backup previo; `--mirror` para cambiarlo |
| A11 | `setup-vmware.sh` completo era ficción | no existe `vmware-tools` en 7.8; `vmtoolsd`/`vmblock` no existen; `vmwgfx` no es driver X ni servicio; el `20-vmwgfx.conf` fijaba tres resoluciones | reescrito: `vmt(4)` (base) + paquete `vmwh`, sin xorg.conf |

---

## 5. Hallazgos medios

- **M1 — Documentación falsa:** «Click Session → Select KDE Plasma»: `xenodm(1)`
  no tiene selector de sesión (corre `~/.xsession`). «`usermod -G audio`»: no
  existe el grupo `audio` en OpenBSD (el audio es sndio).
- **M2 — Paquete inexistente en el README:** `kde-apps` no existe; los metas son
  `kde-plasma`, `kde-plasma-extras` y `kde-<categoría>`. Además `pkg_add dolphin`
  instala el **emulador de GameCube**, no el gestor de archivos (KDE 6 usa
  `kf6-dolphin`).
- **M3 — Enlaces roto:** el README enlazaba `INSTALL.md`, `KDE-CUSTOMIZATION.md`,
  `TROUBLESHOOTING.md`, `CHANGELOG.md` y `output/openbsd-audit-2026-04-03.md`;
  ninguno de los cinco existía.
- **M4 — Sin verificación reproducible:** «syntax-validated» y «tested on real
  OpenBSD systems» no tenían CI ni test que lo respaldara.
- **M5 — Duplicación:** ~60 líneas de cabecera (colores, `print_*`, `check_root`)
  repetidas en los 5 scripts; cualquier corrección había que hacerla cinco veces.

---

## 6. Estado tras 2.1.0

| Área | Antes | Ahora |
|---|---|---|
| Scripts | 5 × autocontenidos, 1 752 líneas | 5 + `lib/common.sh`, cabecera única |
| Flags | ninguno | `--dry-run`, `--yes`, `--verbose`, `--log`, `--help` en todos |
| Backups | 3 archivos, `.bak` reutilizado | manifiesto con sha256, `.orig.<stamp>`, restauración dirigida |
| Verificación | `rcctl check` (= corriendo) | `rcctl get … status` (= habilitado) + binarios + `pkg_info -e` |
| Tests | ninguno | `tests/lint.sh` (33 comprobaciones) y `tests/test-user-setup.sh` (26 comprobaciones: idempotencia, mtime estable, edición del usuario preservada, dry-run, `--help`, marcadores comentados) |
| CI | ninguno | `.github/workflows/ci.yml` en cada push y PR |
| Docs | README + 5 enlaces roto | README + INSTALL + TROUBLESHOOTING + KDE-CUSTOMIZATION + CHANGELOG + SECURITY + este archivo |

Resultados ejecutados en esta auditoría:

```
tests/lint.sh            → 33/33 (sintaxis mksh, shellcheck ksh, shfmt,
                           invariantes, enlaces del README)
tests/test-user-setup.sh → 26/26 (dos corridas reales, mtime, edición del
                           usuario, dry-run, --help, marcadores)
```

---

## 6-bis. Ronda 2 — auditoría independiente de 2.1.0

La corrección se mandó a auditar con **Claude Code (Sonnet, effort medium)**
con un brief que pedía refutar 17 afirmaciones (`SOSTENER`/`MATIZAR`/`REFUTAR`)
y buscar defectos nuevos. Veredicto: **APLICAR CON CAMBIOS**, con 8 defectos
nuevos. Todos eran reales y están corregidos:

| # | Defecto (evidencia del auditor) | Estado |
|---|---|---|
| D1 | **Bloqueante:** nada ejecutaba `rcctl enable messagebus` y la verificación lo exigía → instalación limpia terminaba en exit 1 | ✅ `configure_dbus()` |
| D2 | `backup_file` + `write_file` no preservaban nada en HOME limpio; una edición del usuario en `~/.xsession` se perdía sin copia en la 3ª corrida (lo reprodujo: `ORIG == GENERATED`) | ✅ `write_file` compara contenido: no reescribe si es idéntico y respalda sólo si difiere |
| D3 | `syspatch -l` (instalados) rotulado «pending»; el flag correcto es `-c` | ✅ |
| D4 | `cmd \| awk … \|\| echo fallback`: el fallback nunca corre porque el estado es el de `awk` | ✅ variable + `[ -n ]` |
| D5 | `append_block` usaba `grep -qF`: `#mouse.tp.tapping=1` contaba como configurado | ✅ `_has_marker` con awk, sólo líneas activas |
| D6 | `rollback.sh` no revertía `rcctl enable` ni borraba archivos creados por el instalador | ✅ manifiesto tipado `FILE`/`ABSENT`/`SERVICE` |
| D7 | `_fail` de `install_packages` se contaba y no se reportaba: un `polkit` fallido pasaba la verificación | ✅ `check_fail` con el conteo |
| D8 | «utility scripts executable» se imprimía aunque faltara uno; `--hidpi` sin validar | ✅ conteo + validación numérica |

También refutó a medias **B1** («se habilita `messagebus`»): era falso en el
commit auditado y por eso D1 era bloqueante. El texto quedó correcto recién con
el arreglo.

Lo que el auditor **sostuvo**: que no había bashismos (`mksh -n` en los 9
archivos y en los 8 generados), que el dry-run de `setup-user.sh` no escribe
nada, que `rollback.sh` no usa `=~` y ordena bien los backups, y que
`append_block`/`summary` se usan siempre dentro de `if` (no abortan bajo
`set -e`). Declaró no verificable el `+CONTENTS` de `kde-plasma` (yo sí lo
verifiqué: 46 `@depend`, incluidos `plasma-desktop`, `plasma-workspace`, `kwin`,
`kscreenlocker`, `kf6-dolphin` y `konsole`).

Sus reservas que quedan como límite conocido: **CI no instala `shfmt`** (el paso
se omite si falta) y el chequeo de enlaces sólo mira `.md` del README.

### Lo que sigue sin verificar (y por qué)

`setup-root.sh` **no se ejecutó en hardware OpenBSD**: exige `uname -s = OpenBSD`
por diseño y aquí no hay una máquina 7.8. Lo que sí se verificó, contra fuentes
primarias, es cada nombre de paquete, cada daemon y cada binario que el script
usa. La prueba pendiente es una sola:

```sh
# en una VM OpenBSD 7.8 con los sets X11
doas ksh setup-root.sh --dry-run     # revisar la lista de acciones
doas ksh setup-root.sh               # instalación real
ksh setup-user.sh
doas reboot
ksh validate-install.sh
```

Si algo falla ahí, el log (`/var/log/openbsd-kde-setup-<stamp>.log`) y
`rollback.sh --list` dejan el sistema en un estado reversible.

---

## 7. Cómo reproducir esta auditoría

```sh
git clone --depth 50 https://github.com/azazelpy/openbsd.git
cd openbsd && git log --oneline | head -3

# 1. ¿existe el paquete?
curl -s https://ftp.openbsd.org/pub/OpenBSD/7.8/packages/amd64/index.txt \
  | grep -oE '[a-z0-9._+-]+\.tgz' | grep -E '^(dbus|messagebus|tmux|kde-plasma)-'

# 2. ¿qué instala exactamente?
curl -sO https://ftp.openbsd.org/pub/OpenBSD/7.8/packages/amd64/dbus-1.16.2p1v0.tgz
tar xzf dbus-1.16.2p1v0.tgz +CONTENTS && grep rcscript +CONTENTS

# 3. ¿el script se interpreta en ksh de OpenBSD (pdksh)?
brew install mksh && mksh -n rollback.sh

# 4. ¿el ksh de OpenBSD lee ~/.kshrc sin ENV?
open https://man.openbsd.org/ksh     # sección ENV
```
