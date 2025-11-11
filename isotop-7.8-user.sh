#!/bin/ksh

# isotop-user.sh - OpenBSD 7.8 User Configuration
# Run as: ksh isotop-user.sh (NOT as root)

set -e

RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m'

if [ "$(id -u)" = "0" ]; then
	printf "%s%s%s\\n" "$RED" "ERROR: Do NOT run as root" "$NC"
	exit 1
fi

printf "%s%s%s\\n" "$GREEN" "OK Running as: $(whoami)" "$NC"

printf "%s%s%s\\n" "$BLUE" "==> Creating directories..." "$NC"
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.cache"
mkdir -p "$HOME/.local/share"
printf "%s%s%s\\n" "$GREEN" "OK Directories ready" "$NC"

printf "%s%s%s\\n" "$BLUE" "==> Creating .xsession..." "$NC"
if [ -f "$HOME/.xsession" ]; then
	cp "$HOME/.xsession" "$HOME/.xsession.bak"
	printf "%s%s%s\\n" "$YELLOW" "! Backed up existing .xsession" "$NC"
fi

printf '%s\n' '#!/bin/ksh' > "$HOME/.xsession"
printf '%s\n' 'export LANG=en_US.UTF-8' >> "$HOME/.xsession"
printf '%s\n' 'export LC_ALL=en_US.UTF-8' >> "$HOME/.xsession"
printf '%s\n' 'eval "$(dbus-launch --sh-syntax)"' >> "$HOME/.xsession"
printf '%s\n' 'exec startxfce4' >> "$HOME/.xsession"

chmod 700 "$HOME/.xsession"
printf "%s%s%s\\n" "$GREEN" "OK .xsession created" "$NC"

printf "%s%s%s\\n" "$BLUE" "==> Creating .xinitrc..." "$NC"
if [ -f "$HOME/.xinitrc" ]; then
	cp "$HOME/.xinitrc" "$HOME/.xinitrc.bak"
	printf "%s%s%s\\n" "$YELLOW" "! Backed up existing .xinitrc" "$NC"
fi

printf '%s\n' '#!/bin/ksh' > "$HOME/.xinitrc"
printf '%s\n' 'export LANG=en_US.UTF-8' >> "$HOME/.xinitrc"
printf '%s\n' 'export LC_ALL=en_US.UTF-8' >> "$HOME/.xinitrc"
printf '%s\n' 'eval "$(dbus-launch --sh-syntax)"' >> "$HOME/.xinitrc"
printf '%s\n' 'if command -v startxfce4 >/dev/null 2>&1; then' >> "$HOME/.xinitrc"
printf '%s\n' '	exec startxfce4' >> "$HOME/.xinitrc"
printf '%s\n' 'else' >> "$HOME/.xinitrc"
printf '%s\n' '	exec xterm' >> "$HOME/.xinitrc"
printf '%s\n' 'fi' >> "$HOME/.xinitrc"

chmod 700 "$HOME/.xinitrc"
printf "%s%s%s\\n" "$GREEN" "OK .xinitrc created" "$NC"

printf "%s%s%s\\n" "$BLUE" "==> Updating .profile..." "$NC"
if ! grep -q "isotop" "$HOME/.profile" 2>/dev/null; then
	printf '\\n' >> "$HOME/.profile"
	printf '%s\n' '# isotop configuration' >> "$HOME/.profile"
	printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
	printf '%s\n' 'export EDITOR="vim"' >> "$HOME/.profile"
	printf '%s\n' 'export VISUAL="vim"' >> "$HOME/.profile"
	printf '%s\n' 'export PAGER="less"' >> "$HOME/.profile"
	printf '%s\n' 'export LANG="en_US.UTF-8"' >> "$HOME/.profile"
	printf '%s\n' 'export LC_ALL="en_US.UTF-8"' >> "$HOME/.profile"
	printf "%s%s%s\\n" "$GREEN" "OK .profile updated" "$NC"
else
	printf "%s%s%s\\n" "$YELLOW" "! .profile already configured" "$NC"
fi

printf "%s%s%s\\n" "$BLUE" "==> Updating .kshrc..." "$NC"
if ! grep -q "isotop" "$HOME/.kshrc" 2>/dev/null; then
	printf '\\n' >> "$HOME/.kshrc"
	printf '%s\n' '# isotop configuration' >> "$HOME/.kshrc"
	printf '%s\n' "alias ll='ls -lah'" >> "$HOME/.kshrc"
	printf '%s\n' "alias la='ls -la'" >> "$HOME/.kshrc"
	printf '%s\n' "alias l='ls -CF'" >> "$HOME/.kshrc"
	printf '%s\n' "alias grep='grep --color=auto'" >> "$HOME/.kshrc"
	printf '%s\n' 'mkcd() { mkdir -p "$1"; cd "$1"; }' >> "$HOME/.kshrc"
	printf "%s%s%s\\n" "$GREEN" "OK .kshrc updated" "$NC"
else
	printf "%s%s%s\\n" "$YELLOW" "! .kshrc already configured" "$NC"
fi

printf "%s%s%s\\n" "$BLUE" "==> Setting up Xfce..." "$NC"
mkdir -p "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"

if [ ! -f "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" ]; then
	cat > "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" << 'XFWM4END'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="activate_raise" type="bool" value="true"/>
    <property name="click_to_focus" type="bool" value="true"/>
    <property name="theme" type="string" value="Default"/>
  </property>
</channel>
XFWM4END
	printf "%s%s%s\\n" "$GREEN" "OK Xfce WM config created" "$NC"
fi

printf "%s%s%s\\n" "$BLUE" "==> Setting up autostart..." "$NC"
mkdir -p "$HOME/.config/autostart"
printf "%s%s%s\\n" "$GREEN" "OK Autostart directory ready" "$NC"

printf "%s%s%s\\n" "$BLUE" "==> Configuring input devices..." "$NC"
if [ ! -f "$HOME/.wsconsctl.conf" ]; then
	printf '%s\n' 'mouse.tp.tapping=1' > "$HOME/.wsconsctl.conf"
	printf "%s%s%s\\n" "$GREEN" "OK Input config created" "$NC"
fi

printf "%s%s%s\\n" "$BLUE" "==> Creating utility scripts..." "$NC"
mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/lock-screen" << 'LOCKEND'
#!/bin/sh
if command -v slock >/dev/null 2>&1; then
	slock
else
	xlock -mode blank
fi
LOCKEND
chmod 755 "$HOME/.local/bin/lock-screen"

cat > "$HOME/.local/bin/session-info" << 'INFOEND'
#!/bin/ksh
echo "OpenBSD Session Info"
echo "====================="
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "OpenBSD: $(uname -r)"
echo "Arch: $(uname -m)"
INFOEND
chmod 755 "$HOME/.local/bin/session-info"

printf "%s%s%s\\n" "$GREEN" "OK Utility scripts created" "$NC"

printf "%s%s%s\\n" "$BLUE" "==> Verifying configuration..." "$NC"
PASS=0
FAIL=0

if [ -f "$HOME/.xsession" ]; then
	printf "%s%s%s\\n" "$GREEN" "OK .xsession OK" "$NC"
	PASS=$((PASS + 1))
else
	printf "%s%s%s\\n" "$RED" "ERROR .xsession missing" "$NC"
	FAIL=$((FAIL + 1))
fi

if [ -f "$HOME/.xinitrc" ]; then
	printf "%s%s%s\\n" "$GREEN" "OK .xinitrc OK" "$NC"
	PASS=$((PASS + 1))
else
	printf "%s%s%s\\n" "$RED" "ERROR .xinitrc missing" "$NC"
	FAIL=$((FAIL + 1))
fi

if [ -d "$HOME/.config" ]; then
	printf "%s%s%s\\n" "$GREEN" "OK Config dir OK" "$NC"
	PASS=$((PASS + 1))
else
	printf "%s%s%s\\n" "$RED" "ERROR Config dir missing" "$NC"
	FAIL=$((FAIL + 1))
fi

if [ -d "$HOME/.local/bin" ]; then
	printf "%s%s%s\\n" "$GREEN" "OK Scripts dir OK" "$NC"
	PASS=$((PASS + 1))
else
	printf "%s%s%s\\n" "$RED" "ERROR Scripts dir missing" "$NC"
	FAIL=$((FAIL + 1))
fi

printf "\\n%s%s%s\\n" "$BLUE" "========================================" "$NC"
printf "%s%s%s\\n" "$GREEN" "  User Configuration Complete!" "$NC"
printf "%s%s%s\\n" "$BLUE" "========================================" "$NC"
printf "\\n"
echo "Files created:"
echo "  ~/.xsession      - Xfce session (xenodm)"
echo "  ~/.xinitrc       - X init (startx)"
echo "  ~/.profile       - Shell environment"
echo "  ~/.kshrc         - Ksh aliases"
echo "  ~/.config/       - Xfce settings"
echo "  ~/.local/bin/    - Utility scripts"
printf "\\n"
echo "Checks: $PASS passed, $FAIL failed"
printf "\\n"
echo "Next: Log out and login via xenodm"
echo "  or: Type startx at console"
printf "\\n"

exit $FAIL
