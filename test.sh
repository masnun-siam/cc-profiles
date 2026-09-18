#!/usr/bin/env bash
# Self-check: builds a throwaway profile in a temp root with a stub `claude`.
# Touches nothing real. Exits non-zero on the first failure.
set -euo pipefail
cd "$(dirname "$0")"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
printf '#!/bin/sh\necho "$CLAUDE_CONFIG_DIR"\n' > "$TMP/bin/claude"
chmod +x "$TMP/bin/claude"

DIR="$TMP/root/t1"
out=$(CC_PROFILE_ROOT="$TMP/root" PATH="$TMP/bin:$PATH" ./cc-profile.sh t1)

fail() { echo "FAIL: $1" >&2; exit 1; }

[ "$out" = "$DIR" ] || fail "claude ran with CLAUDE_CONFIG_DIR=$out, expected $DIR"

# shared entries are symlinks that resolve
for n in skills agents commands settings.json plugins/installed_plugins.json; do
  [ -e "$HOME/.claude/$n" ] || continue   # skip what this machine doesn't have
  [ -L "$DIR/$n" ] || fail "$n is not a symlink"
  [ -e "$DIR/$n" ] || fail "$n symlink is broken"
done
[ -e "$DIR/skills" ] || fail "no skills linked at all"

# identity and concurrently-written state must NOT be shared
for n in projects sessions history.jsonl .credentials.json plugins/cache; do
  [ -e "$DIR/$n" ] && fail "$n should not exist in a fresh profile"
done

# seeded config has MCP servers and no account
python3 - "$DIR/.claude.json" <<'PY' || exit 1
import json, sys
d = json.load(open(sys.argv[1]))
assert "mcpServers" in d, "mcpServers missing from seeded .claude.json"
assert "oauthAccount" not in d, "oauthAccount leaked into seeded .claude.json"
PY

# second run is idempotent
CC_PROFILE_ROOT="$TMP/root" PATH="$TMP/bin:$PATH" ./cc-profile.sh t1 >/dev/null

# bad usage is rejected
if CC_PROFILE_ROOT="$TMP/root" PATH="$TMP/bin:$PATH" ./cc-profile.sh 2>/dev/null; then
  fail "missing profile name should exit non-zero"
fi

echo "ok"
