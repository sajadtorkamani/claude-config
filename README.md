# claude-config

My personal [Claude Code](https://claude.com/claude-code) config: skills, hooks and global instructions.

## Install

```bash
git clone git@github.com:sajadtorkamani/claude-config.git ~/code/claude-config
~/code/claude-config/install.sh
```

`install.sh` symlinks each folder in `skills/` into `~/.claude/skills/` and `CLAUDE.md` into `~/.claude/CLAUDE.md`, so edits here take effect immediately, and merges `hooks.json` into `~/.claude/settings.json`. Re-run it after adding a new skill or changing a hook.

## CLAUDE.md

`CLAUDE.md` holds the global instructions Claude Code loads for every project on this machine.

## Hooks

`hooks.json` holds hooks that get merged into `~/.claude/settings.json`. Both currently call
`bin/notify.sh`, which shows a macOS notification:

| Event | Notification |
| --- | --- |
| `Stop` — Claude finished a turn | "Finished — turn complete" |
| `Notification` — Claude needs you | "Waiting for your input" |

The notification is titled with the project name, so you can tell which repo it came from. That
name is the git repo's root folder (a subdirectory of the repo still reports the repo), falling
back to the plain folder name outside a repo. It's read from the `cwd` in the hook payload on
stdin, falling back to the working directory.

### How it's installed

`install.sh` symlinks `bin/` into `~/.claude/bin/`, so `hooks.json` can name
`$HOME/.claude/bin/notify.sh` literally rather than hardcoding wherever this repo is cloned.

The hooks are merged into `settings.json` rather than symlinked, because Claude Code writes to
that file itself (permissions, theme) and each machine needs to keep its own. Entries carry a
`# claude-config:` marker and the merge strips anything matching that prefix before re-adding,
so re-running `install.sh` replaces rather than duplicates. The merge only adds and replaces, so
deleting a hook here won't remove it from a machine already installed on — delete it from that
machine's `settings.json`.

Requires `jq`, and it's macOS-only (`osascript`). `install.sh` skips the merge with a message if
either is missing, and `notify.sh` exits quietly on other platforms.

If notifications don't appear, macOS needs to allow them for your terminal app under System
Settings → Notifications.

## Skills

- `commit`: commits changes with a concise title (≤72 chars) and an optional description.
- `commit-and-push`: runs `commit`, then pushes the branch to the remote.
- `delegate-task`: does a task end to end in a throwaway worktree, then opens a draft PR into the branch you pick — assigned to you, labelled `claude`, with the description already written.
- `pr-summary`: asks for the base branch and any related PRs, then summarises the branch's commits as markdown for the GitHub PR description.
- `review-handoff`: asks for the base branch, then writes a review prompt for another agentic CLI (Codex, Gemini CLI, a fresh Claude Code session) to run in the same checkout, and triages the findings you paste back.
- `summarise-changes`: recaps the uncommitted work and unpushed commits in the current repo, for when you've lost track of what you were doing.
