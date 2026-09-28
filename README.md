# claude-config

My personal [Claude Code](https://claude.com/claude-code) skills.

## Install

```bash
git clone git@github.com:sajadtorkamani/claude-config.git ~/code/claude-config
~/code/claude-config/install.sh
```

`install.sh` symlinks each folder in `skills/` into `~/.claude/skills/` and `CLAUDE.md` into `~/.claude/CLAUDE.md`, so edits here take effect immediately, and merges `hooks.json` into `~/.claude/settings.json`. Re-run it after adding a new skill or changing a hook.

## CLAUDE.md

`CLAUDE.md` holds the global instructions Claude Code loads for every project on this machine.

## Hooks

`hooks.json` holds hooks that get merged into `~/.claude/settings.json`. Currently it plays a
sound when Claude finishes a turn (`Stop`, Glass) and when Claude needs your input (`Notification`,
Funk). Swap the sounds for anything in `/System/Library/Sounds/`.

It's a merge rather than a symlink because `settings.json` is a live file Claude Code writes to
(permissions, theme), so each machine keeps its own. Entries carry a `# claude-config:sound`
marker, so re-running `install.sh` replaces them instead of stacking duplicates — and removing a
hook here does not remove it from a machine you've already installed on; delete it from that
machine's `settings.json`.

Requires `jq`, and the sounds are macOS-only (`afplay`). `install.sh` skips this step with a
message if either is missing.

## Skills

- `commit`: commits changes with a concise title (≤72 chars) and an optional description.
- `commit-and-push`: runs `commit`, then pushes the branch to the remote.
- `delegate-task`: does a task end to end in a throwaway worktree, then opens a draft PR into the branch you pick — assigned to you, labelled `claude`, with the description already written.
- `pr-summary`: asks for the base branch and any related PRs, then summarises the branch's commits as markdown for the GitHub PR description.
- `review-handoff`: asks for the base branch, then writes a review prompt for another agentic CLI (Codex, Gemini CLI, a fresh Claude Code session) to run in the same checkout, and triages the findings you paste back.
- `summarise-changes`: recaps the uncommitted work and unpushed commits in the current repo, for when you've lost track of what you were doing.
