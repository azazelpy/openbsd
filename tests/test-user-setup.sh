#!/bin/sh
# ============================================================================
# tests/test-user-setup.sh - behavioural test for setup-user.sh
# ============================================================================
# Runs setup-user.sh for real against a throw-away HOME, twice (idempotency),
# then once more with --dry-run against an empty HOME and asserts that nothing
# was written. No OpenBSD required: it only creates files under $HOME.
#
#   ./tests/test-user-setup.sh
# ============================================================================

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
shell=''
if command -v mksh >/dev/null 2>&1; then
	shell=mksh
elif command -v ksh >/dev/null 2>&1; then
	shell=ksh
else
	printf 'FAIL: neither mksh nor ksh installed\n'
	exit 1
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/openbsd-kde-test.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT INT TERM

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

assert_file() {
	[ -f "$1" ] && ok "exists: $1" || bad "missing: $1"
}

assert_exec() {
	[ -x "$1" ] && ok "executable: $1" || bad "not executable: $1"
}

assert_contains() {
	if grep -q "$2" "$1" 2>/dev/null; then
		ok "$(basename "$1") contains: $2"
	else
		bad "$(basename "$1") does not contain: $2"
	fi
}

printf '== run 1: fresh HOME\n'
export HOME="$tmp/home1"
mkdir -p "$HOME"
if "$shell" "$root/setup-user.sh" --yes >"$tmp/run1.log" 2>&1; then
	ok "setup-user.sh exited 0"
else
	bad "setup-user.sh failed (see below)"
	cat "$tmp/run1.log"
fi

assert_exec "$HOME/.xsession"
assert_exec "$HOME/.xinitrc"
assert_file "$HOME/.profile"
assert_file "$HOME/.kshrc"
assert_file "$HOME/.config/kdeglobals"
for s in system-info lock-screen kde-restart update-system; do
	assert_exec "$HOME/.local/bin/$s"
done

printf '\n== content of the generated session\n'
assert_contains "$HOME/.xsession" 'startplasma-x11'
if grep -q '^exec startkde' "$HOME/.xsession" 2>/dev/null; then
	bad "~/.xsession execs bare startkde (not available in Plasma 6)"
else
	ok "~/.xsession does not exec bare startkde"
fi
assert_contains "$HOME/.profile" '^export ENV=.*\.kshrc'
assert_contains "$HOME/.local/bin/lock-screen" 'dbus-send'

printf '\n== run 2: idempotency\n'
if "$shell" "$root/setup-user.sh" --yes >"$tmp/run2.log" 2>&1; then
	ok "second run exited 0"
else
	bad "second run failed"
	cat "$tmp/run2.log"
fi

orig_count=$(ls -1 "$HOME"/.xsession.orig.* 2>/dev/null | wc -l | tr -d ' ')
if [ "$orig_count" -eq 0 ]; then
	# The second run writes byte-identical content, so there is nothing to
	# preserve and no backup file is created (this used to create one).
	ok "re-run with identical content created no .orig backup"
else
	bad "expected 0 .orig backups on an unchanged re-run, found $orig_count"
fi

# Nothing changed, so the file must not be rewritten. Compare against a
# reference file instead of parsing mtime: `stat -f %m` is BSD-only and on
# GNU coreutils -f means "file system", which prints a changing report.
ref="$tmp/mtime-ref"
: >"$ref"
sleep 1
"$shell" "$root/setup-user.sh" --yes >"$tmp/run2b.log" 2>&1
if [ "$HOME/.xsession" -nt "$ref" ]; then
	bad "re-run rewrote ~/.xsession even though the content was identical"
else
	ok "unchanged re-run did not rewrite ~/.xsession"
fi

marker_count=$(grep -c 'openbsd-kde-suite' "$HOME/.profile")
if [ "$marker_count" -eq 2 ]; then
	ok "profile block not duplicated (2 marker lines: open+close)"
else
	bad "profile block duplicated ($marker_count marker lines)"
fi

printf '\n== run 2c: a user edit must be preserved, not silently lost\n'
printf '# my custom line\n' >>"$HOME/.xsession"
if "$shell" "$root/setup-user.sh" --yes >"$tmp/run2c.log" 2>&1; then
	ok "run after a manual edit exited 0"
else
	bad "run after a manual edit failed"
	cat "$tmp/run2c.log"
fi
if grep -l 'my custom line' "$HOME"/.xsession.orig.* >/dev/null 2>&1; then
	ok "the edited version was preserved in .xsession.orig.*"
else
	bad "the user edit was overwritten without a backup"
fi
if grep -q 'my custom line' "$HOME/.xsession"; then
	bad "regenerated file kept the edit (unexpected)"
else
	ok "generated file regenerated cleanly"
fi

printf '\n== run 3: --dry-run must not write\n'
export HOME="$tmp/home2"
mkdir -p "$HOME"
if "$shell" "$root/setup-user.sh" --dry-run --yes >"$tmp/run3.log" 2>&1; then
	ok "dry-run exited 0"
else
	bad "dry-run failed"
	cat "$tmp/run3.log"
fi
written=$(find "$HOME" -type f | wc -l | tr -d ' ')
if [ "$written" -eq 0 ]; then
	ok "dry-run created no files"
else
	bad "dry-run created $written files"
	find "$HOME" -type f | sed 's/^/       /'
fi

printf '\n== run 4: --help exits 0 and prints usage\n'
if "$shell" "$root/setup-user.sh" --help >"$tmp/help.log" 2>&1 &&
	grep -q 'setup-user.sh - OpenBSD KDE Desktop Suite' "$tmp/help.log"; then
	ok "--help works"
else
	bad "--help broken"
fi

printf '\n== marker detection must ignore commented lines\n'
probe=$tmp/probe.sh
cat >"$probe" <<'PROBE'
set -eu
. "$1/lib/common.sh"
f=$2
printf '#mouse.tp.tapping=1\n' > "$f"
if _has_marker "$f" mouse.tp.tapping; then echo COMMENTED_MATCHES; else echo COMMENTED_IGNORED; fi
printf 'mouse.tp.tapping=1\n' >> "$f"
if _has_marker "$f" mouse.tp.tapping; then echo ACTIVE_MATCHES; else echo ACTIVE_MISSED; fi
PROBE
probe_out=$("$shell" "$probe" "$root" "$tmp/marker.conf" 2>&1)
case "$probe_out" in
*COMMENTED_IGNORED*) ok "a commented '#mouse.tp.tapping=1' is not treated as configured" ;;
*) bad "commented marker was treated as configured ($probe_out)" ;;
esac
case "$probe_out" in
*ACTIVE_MATCHES*) ok "an active mouse.tp.tapping=1 is detected" ;;
*) bad "active marker not detected ($probe_out)" ;;
esac

printf '\n== result: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
