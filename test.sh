#!/usr/bin/env bash
# Self-check: builds a throwaway profile in a temp root with a stub `claude`.
# Touches nothing real. Exits non-zero on the first failure.
set -euo pipefail
cd "$(dirname "$0")"

CC_BIN="${CC_BIN:-./bin/cc-profile}"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
printf '#!/bin/sh\necho "$CLAUDE_CONFIG_DIR"\n' > "$TMP/bin/claude"
chmod +x "$TMP/bin/claude"

DIR="$TMP/root/t1"
out=$(CC_PROFILE_ROOT="$TMP/root" PATH="$TMP/bin:$PATH" $CC_BIN t1)

fail() { echo "FAIL: $1" >&2; exit 1; }

[ "$out" = "$DIR" ] || fail "claude ran with CLAUDE_CONFIG_DIR=$out, expected $DIR"

# shared entries are symlinks that resolve
for n in skills agents commands plugins settings.json; do
  [ -e "$HOME/.claude/$n" ] || continue   # skip what this machine doesn't have
  [ -L "$DIR/$n" ] || fail "$n is not a symlink"
  [ -e "$DIR/$n" ] || fail "$n symlink is broken"
done
[ -e "$DIR/skills" ] || fail "no skills linked at all"

# plugins are shared whole, so installed plugin code is reachable
[ -d "$DIR/plugins/cache" ] || fail "plugin cache not reachable through the profile"

# identity and per-profile state must NOT be shared
for n in projects sessions history.jsonl .credentials.json; do
  [ -e "$DIR/$n" ] && fail "$n should not exist in a fresh profile"
done

# a real directory the profile already owns must not get a link nested inside it
mkdir -p "$DIR/skills"/.keep 2>/dev/null || true
rm -f "$DIR/skills" 2>/dev/null || true
mkdir -p "$DIR/skills"
CC_PROFILE_ROOT="$TMP/root" PATH="$TMP/bin:$PATH" $CC_BIN t1 >/dev/null 2>&1
[ -L "$DIR/skills" ] && fail "clobbered a real skills dir"
[ -e "$DIR/skills/skills" ] && fail "nested a link inside a real skills dir"
rmdir "$DIR/skills"

# seeded config has MCP servers and no account
python3 - "$DIR/.claude.json" <<'PY' || exit 1
import json, sys
d = json.load(open(sys.argv[1]))
assert "mcpServers" in d, "mcpServers missing from seeded .claude.json"
assert "oauthAccount" not in d, "oauthAccount leaked into seeded .claude.json"
PY

# second run is idempotent
CC_PROFILE_ROOT="$TMP/root" PATH="$TMP/bin:$PATH" $CC_BIN t1 >/dev/null

# bad usage is rejected
if CC_PROFILE_ROOT="$TMP/root" PATH="$TMP/bin:$PATH" $CC_BIN 2>/dev/null; then
  fail "missing profile name should exit non-zero"
fi

echo "ok"
