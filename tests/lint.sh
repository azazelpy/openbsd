#!/bin/sh
# ============================================================================
# tests/lint.sh - static checks for the whole suite
# ============================================================================
# Runs anywhere with a pdksh-compatible shell (mksh preferred, ksh accepted)
# and shellcheck. Exit 0 only when every check passes.
#
#   ./tests/lint.sh
#
# This is what CI runs. Each forbidden pattern encodes a bug that shipped in
# 2.0.0; keeping the rule keeps the bug from coming back.
# ============================================================================

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 1

fail=0
pass=0

ok() {
	printf '  [ok]   %s\n' "$1"
	pass=$((pass + 1))
}

bad() {
	printf '  [FAIL] %s\n' "$1"
	fail=$((fail + 1))
}

scripts=$(ls ./*.sh lib/*.sh 2>/dev/null)

printf '== shell selection\n'
shell=''
if command -v mksh >/dev/null 2>&1; then
	shell=mksh
elif command -v ksh >/dev/null 2>&1; then
	shell=ksh
fi
if [ -n "$shell" ]; then
	ok "using $shell"
else
	bad "neither mksh nor ksh is installed"
fi

printf '\n== syntax (%s -n)\n' "${shell:-no shell}"
if [ -n "$shell" ]; then
	for f in $scripts; do
		if err=$($shell -n "$f" 2>&1); then
			ok "$f parses"
		else
			bad "$f does not parse: $err"
		fi
	done
fi

printf '\n== shellcheck (ksh dialect, warnings and above)\n'
if command -v shellcheck >/dev/null 2>&1; then
	for f in $scripts; do
		if out=$(shellcheck -s ksh -S warning -f gcc "$f" 2>&1); then
			ok "$f clean"
		else
			bad "$f: $out"
		fi
	done
else
	printf '  [skip] shellcheck not installed\n'
fi

printf '\n== formatting (shfmt, mksh dialect)\n'
if command -v shfmt >/dev/null 2>&1; then
	for f in $scripts; do
		if out=$(shfmt -ln mksh -d "$f" 2>&1); then
			ok "$f formatted"
		else
			bad "$f not formatted - run: shfmt -ln mksh -w $f"
			printf '%s\n' "$out" | head -20
		fi
	done
else
	printf '  [skip] shfmt not installed\n'
fi

printf '\n== forbidden patterns (2.0.0 regressions)\n'
hits=0
while IFS='|' read -r pat why; do
	case "$pat" in '' | '#'*) continue ;; esac
	for f in $scripts; do
		# Ignore comment lines: the suite documents these traps on purpose.
		if sed 's/^[[:space:]]*#.*$//' "$f" | grep -qE "$pat"; then
			bad "$f matches /$pat/ -> $why"
			hits=$((hits + 1))
		fi
	done
done <<'PATTERNS'
exec startkde|Plasma 6 ships startplasma-x11, not startkde
kern\.sbmax=|not a sysctl in OpenBSD
kern\.somaxkva=|not a sysctl in OpenBSD
pkg_add messagebus|the package is named dbus
pkg_add vmware-tools|no such package on OpenBSD 7.8
pkg_add tmux|tmux is part of the base system
rcctl enable polkit|polkit has no rc.d script (D-Bus activated)
rcctl enable consolekit2|consolekit2 has no rc.d script
read -p |read -p is a bashism
=~ *\^|ksh (pdksh) has no =~ operator
\.config/dolphinrc|dolphinrc is a file, not a directory
PATTERNS
[ "$hits" -eq 0 ] && ok "no forbidden pattern found"

printf '\n== repository invariants\n'
for f in $scripts; do
	if [ -x "$f" ]; then
		ok "$f is executable"
	else
		bad "$f is not executable (chmod +x)"
	fi
done

if grep -q "$(printf '\r')" $scripts 2>/dev/null; then
	bad "CRLF line endings found"
else
	ok "no CRLF line endings"
fi

# Every markdown file linked from the README must exist.
for target in $(sed -n 's/.*](\([A-Za-z0-9._/-]*\.md\)).*/\1/p' README.md | sort -u); do
	if [ -f "$target" ]; then
		ok "README link resolves: $target"
	else
		bad "README links to a missing file: $target"
	fi
done

printf '\n== result: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
