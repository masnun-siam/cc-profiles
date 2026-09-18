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
brew install masnun-siam/tap/cc-profiles
```

Or without Homebrew:

```bash
git clone https://github.com/masnun-siam/cc-profiles.git
sudo ln -s "$PWD/cc-profiles/bin/cc-profile" /usr/local/bin/cc-profile
```

Optionally shorten it. Do **not** name it `cc` on `$PATH` — that's the C compiler.
An interactive shell alias is safe, since aliases don't affect scripts or `make`:

```bash
echo "alias cc='cc-profile'" >> ~/.zshrc   # or ~/.bashrc
```

## Use

```bash
cc-profile work            # Claude Code as the "work" account
cc-profile work -p "hi"    # extra args pass straight through to claude
claude                     # your original account, in another terminal, at the same time
```

The first time you open a new profile, run `/login` inside it. That's it — profiles are
created on demand, so a third account is just `cc-profile client-x`.

Profiles live in `~/.claude-profiles/<name>/`.

## What's shared, what isn't

**Shared** — symlinked to `~/.claude`, so it stays live: add a skill once and every
profile sees it immediately.

```
skills  agents  commands  hooks  plugins  CLAUDE.md
settings.json  output-styles  statusline-command.sh
```

Requires bash (3.2 is fine, so stock macOS works) and, optionally, `python3` to copy
your MCP server list into a new profile — without it the profile starts with none.

`plugins/` is shared whole — the marketplace registry, the installed plugin code in
`plugins/cache/`, and each plugin's own state in `plugins/data/`. Install a plugin once
and every profile has it, at the same version, with the same data.

**Separate** — each profile gets its own:

```
credentials  .claude.json  projects  sessions
history.jsonl  todos  shell-snapshots
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
- Plugin state in `plugins/data/` is shared too, so a plugin that keeps a database
  (memory plugins, workflow trackers) sees both accounts' activity as one stream. That
  is usually what you want from one person with two accounts, but it does mean two
  running profiles write to the same files.
- Usage limits are per-account. That's the point.
- Credentials really are per-profile. Claude Code stores `.credentials.json` under
  `CLAUDE_CONFIG_DIR`, and on macOS
  [keys the Keychain entry to that directory too](https://code.claude.com/docs/en/authentication#credential-management),
  so a session with a different config dir reads a different entry. Two logins coexist.

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

Then the live check:

1. Terminal A: `cc-profile work`, `/login` with the second account.
2. Terminal B, at the same time: `claude`, then `/status`. It shows your original
   account, and A stays logged in.
3. In A: `/skills`, `/agents` and `/plugin` list the same entries as B; `/mcp` shows
   your servers.

## Uninstall

```bash
rm -rf ~/.claude-profiles
```

and remove the alias. Nothing under `~/.claude` is ever modified — the script only
reads from it and creates symlinks pointing at it.

## License

MIT
