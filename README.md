# claude-config

My personal [Claude Code](https://claude.com/claude-code) skills.

## Install

```bash
git clone git@github.com:sajadtorkamani/claude-config.git ~/code/claude-config
~/code/claude-config/install.sh
```

`install.sh` symlinks each folder in `skills/` into `~/.claude/skills/` and `CLAUDE.md` into `~/.claude/CLAUDE.md`, so edits here take effect immediately. Re-run it after adding a new skill.

## CLAUDE.md

`CLAUDE.md` holds the global instructions Claude Code loads for every project on this machine.

## Skills

- `commit`: commits changes with a concise title (≤72 chars) and an optional description.
- `commit-and-push`: runs `commit`, then pushes the branch to the remote.
- `pr-summary`: asks for the base branch and any related PRs, then summarises the branch's commits as markdown for the GitHub PR description.
- `summarise-changes`: recaps the uncommitted work and unpushed commits in the current repo, for when you've lost track of what you were doing.
