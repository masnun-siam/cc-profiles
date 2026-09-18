#!/usr/bin/env bash
# Run a second (third, ...) Claude Code account in parallel with your main one.
#   cc work            -> opens Claude Code as the "work" account
#   cc work -p "hi"    -> args pass through to claude
set -euo pipefail

SRC="${CC_PROFILE_SRC:-$HOME/.claude}"
ROOT="${CC_PROFILE_ROOT:-$HOME/.claude-profiles}"

# Shared with the main config dir via symlink. Adding a skill/agent/command/plugin
# to ~/.claude shows up in every profile immediately — whole directories are linked.
SHARED=(skills agents commands hooks plugins CLAUDE.md settings.json output-styles statusline-command.sh)

usage() { echo "usage: cc <profile> [claude args...]" >&2; exit 2; }
[ $# -ge 1 ] || usage
case "$1" in -*|"") usage;; esac

PROFILE=$1; shift
DIR="$ROOT/$PROFILE"

mkdir -p "$DIR"

for name in "${SHARED[@]}"; do
  [ -e "$SRC/$name" ] || continue
  # Never link into a real directory the profile already built on its own —
  # `ln -sfn` would nest the link inside it instead of replacing it.
  if [ -e "$DIR/$name" ] && [ ! -L "$DIR/$name" ]; then
    echo "cc-profile: $name already exists in $PROFILE, leaving it alone" >&2
    continue
  fi
  ln -sfn "$SRC/$name" "$DIR/$name"
done

# Seed MCP servers once, from the main config. Never copy oauthAccount — that is
# the identity we are deliberately splitting.
if [ ! -e "$DIR/.claude.json" ] && [ -f "$HOME/.claude.json" ]; then
  python3 - "$HOME/.claude.json" "$DIR/.claude.json" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    d = json.load(f)
with open(dst, "w") as f:
    json.dump({"mcpServers": d.get("mcpServers", {})}, f, indent=2)
PY
  chmod 600 "$DIR/.claude.json"
fi

# Extra args prepended to every run. Empty by default; set it if your normal
# `claude` invocation carries flags you want profiles to inherit, e.g.
#   export CC_CLAUDE_ARGS="--allow-dangerously-skip-permissions"
CLAUDE_BIN="${CC_CLAUDE_BIN:-claude}"
read -r -a _extra <<< "${CC_CLAUDE_ARGS:-}"

export CLAUDE_CONFIG_DIR="$DIR"
exec "$CLAUDE_BIN" "${_extra[@]}" "$@"
