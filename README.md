# cc-profiles

Run **two (or more) Claude Code accounts at the same time**, sharing the same skills,
agents, commands, plugins and settings.

Not "log out, log in". Two terminals, two accounts, two sets of usage limits, one
identical setup.

## How it works

Claude Code keeps all of its state in one directory, overridable with the
`CLAUDE_CONFIG_DIR` environment variable. Two directories means two independent
logins. That is the entire trick — this script just creates the second directory and
symlinks the shared parts back to your main `~/.claude`, so you configure things once.

About 50 lines of bash. No dependencies beyond `bash` and `python3` (used once, to
copy your MCP server list into a new profile).

## Install

```bash
git clone https://github.com/masnun-siam/cc-profiles.git
echo 'alias cc="$PWD/cc-profiles/cc-profile.sh"' >> ~/.zshrc   # or ~/.bashrc
```

## Use

```bash
cc work            # Claude Code as the "work" account
cc work -p "hi"    # extra args pass straight through to claude
claude             # your original account, in another terminal, simultaneously
```

The first time you open a new profile, run `/login` inside it. That's it — profiles are
created on demand, so a third account is just `cc client-x`.

Profiles live in `~/.claude-profiles/<name>/`.

## What's shared, what isn't

**Shared** — symlinked to `~/.claude`, so it stays live: add a skill once and every
profile sees it immediately.

```
skills  agents  commands  hooks  CLAUDE.md  settings.json
output-styles  statusline-command.sh
plugins/{marketplaces,synced,installed_plugins.json,known_marketplaces.json}
```

**Separate** — each profile gets its own:

```
credentials  .claude.json  projects  sessions  history.jsonl
todos  shell-snapshots  plugins/cache  plugins/data
```

Those are written while Claude is running, so sharing them between two live processes
would race. Anything not named in either list is simply left out and recreated by
Claude on first launch.

MCP servers are copied from `~/.claude.json` once, at profile creation, then diverge.
Add later servers with `claude mcp add` inside the profile. The `oauthAccount` key is
deliberately never copied — that's the identity being split.

## Things to know

- `settings.json` is a symlink, so `/config` in **either** profile edits both. If you
  want them to differ, replace the symlink with a copy:
  `cp ~/.claude/settings.json ~/.claude-profiles/work/settings.json`.
- Usage limits are per-account. That's the point.
- macOS: Claude Code may store OAuth tokens in the login Keychain rather than in the
  profile directory. Verify once (see below) before relying on true parallel use.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `CC_PROFILE_ROOT` | `~/.claude-profiles` | where profiles live |
| `CC_PROFILE_SRC` | `~/.claude` | config directory to share from |
| `CC_CLAUDE_BIN` | `claude` | binary to exec |
| `CC_CLAUDE_ARGS` | *(empty)* | args prepended to every run |

If your normal `claude` invocation carries flags, put them in `CC_CLAUDE_ARGS` so
profiles behave identically:

```bash
export CC_CLAUDE_ARGS="--allow-dangerously-skip-permissions"
```

## Verify

```bash
bash test.sh
```

Builds a throwaway profile in a temp directory against a stub `claude`, then asserts
the shared symlinks resolve, the private state is absent, the seeded config has
`mcpServers` and no `oauthAccount`, re-running is idempotent, and bad usage exits
non-zero. Touches nothing real.

Then the live check, which also settles the Keychain question:

1. Terminal A: `cc work`, `/login` with the second account.
2. Terminal B, at the same time: `claude`, then `/status`. It should still show your
   original account, and A should still be logged in.
3. In A: `/skills` and `/agents` list the same entries as B; `/mcp` shows your servers.

If B got logged out, the two profiles are sharing one Keychain entry and parallel use
isn't available on your version — please open an issue with your `claude --version`.

## Uninstall

```bash
rm -rf ~/.claude-profiles
```

and remove the alias. Nothing under `~/.claude` is ever modified — the script only
reads from it and creates symlinks pointing at it.

## License

MIT
