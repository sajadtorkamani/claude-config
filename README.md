# claude-config

My personal [Claude Code](https://claude.com/claude-code) config: skills and global instructions.

## Install

```bash
git clone git@github.com:sajadtorkamani/claude-config.git ~/code/claude-config
~/code/claude-config/install.sh
```

`install.sh` symlinks each folder in `skills/` into `~/.claude/skills/` `CLAUDE.md` into `~/.claude/CLAUDE.md`, and `AGENTS.md` into `~/.codex/AGENTS.md` (for Codex), so edits here take effect immediately. Re-run it after adding a new skill.

## AGENTS.md and CLAUDE.md

`AGENTS.md` holds the global instructions for every project on this machine. Claude Code doesn't read `AGENTS.md` itself, so `CLAUDE.md` just imports it (`@~/code/claude-config/AGENTS.md`). Edit `AGENTS.md`, not `CLAUDE.md`.

## Skills

- `commit`: commits changes with a concise title (≤72 chars) and an optional description.
- `commit-and-push`: runs `commit`, then pushes the branch to the remote.
- `delegate-task`: does a task end to end in a throwaway worktree, then opens a draft PR into the branch you pick — assigned to you, labelled `claude`, with the description already written.
- `pr-summary`: asks for the base branch and any related PRs, then summarises the branch's commits as markdown for the GitHub PR description.
- `review-handoff`: asks for the base branch, then writes a review prompt for another agentic CLI (Codex, Gemini CLI, a fresh Claude Code session) to run in the same checkout, and triages the findings you paste back.
- `summarise-changes`: recaps the uncommitted work and unpushed commits in the current repo, for when you've lost track of what you were doing.
