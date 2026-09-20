---
name: summarise-changes
description: Recap the current git changes — uncommitted work plus any commits not yet pushed — so you can pick up where you left off. Use when the user runs /summarise-changes or asks what changes they currently have / what they were working on.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(git merge-base:*), Bash(git stash:*), Bash(git ls-files:*), Bash(gh repo view:*), Read
---

# Summarise changes

Explain what work is currently in progress in this repo, so the user can get back up to speed
without reading the diff themselves.

This skill is **read-only**. Never stage, commit, stash, discard, or push anything.

## Step 1 — Gather context

Run these in parallel (ignore any that fail):

- `git status --short --branch` — branch, upstream, and which files are staged / unstaged / untracked.
- `git diff --stat` and `git diff --staged --stat` — size and shape of the working-tree changes.
- `git log --oneline -10` — recent commits, for context on what the branch is about.
- `git rev-parse --abbrev-ref HEAD` — the current branch.
- `git symbolic-ref --short refs/remotes/origin/HEAD` — the default branch (fall back to `main`).
- `git stash list` — stashes are easy to forget about; mention them if any exist.

Then work out the scope of "current changes":

- **Uncommitted work** — staged, unstaged, and untracked files.
- **Unpushed commits** — if the branch has an upstream, `git log --oneline @{u}..HEAD`. If it has
  no upstream, use the default branch instead: `git log --oneline "$(git merge-base <default> HEAD)"..HEAD`.

If there's nothing at all — clean tree, nothing unpushed, no stashes — say so in one line and stop.

## Step 2 — Read the actual changes

Don't summarise from filenames and diffstats alone. Read the real diff:

- `git diff` and `git diff --staged` for the changed content.
- For untracked files, read the ones that look like real work (`Read` on each); skip generated
  output, lock files, build artefacts, and anything gitignored-but-listed.
- If the diff is very large (say over ~2000 lines), read the most substantial files in full and rely
  on `--stat` for the rest — but say which parts you skimmed.

Aim to understand *why* each change is there, not just what lines moved.

## Step 3 — Report

Write the recap directly in your reply as markdown. No fenced block — this is for reading, not
pasting. Keep it proportionate: a two-file change gets a few lines, not a templated report.

Shape it roughly like this, dropping any section that would be empty:

```
**Branch** `feature/x` — 3 commits ahead of `main`, 5 files changed, 1 untracked.

### In progress (uncommitted)

- **`path/to/file.php`** — what changed and why it's there.
- **`another/file.ts`** — …

### Committed but not pushed

- `abc1234` Commit title — what it did.

### Loose ends

- `TODO` left in `foo.php:42`.
- `debug.log` is untracked and probably shouldn't be committed.
- 1 stash from 3 days ago.
```

Guidelines:

- **Group by intent, not by file.** Several files serving one change become one bullet; a file doing
  two unrelated things gets mentioned under both.
- Lead with what the change *accomplishes*, then name the files. Someone who wrote this code two
  weeks ago should recognise it from the first clause.
- Reference locations as `path/to/file.php:42` so they're clickable.
- Call out anything that looks unfinished or accidental: leftover debug statements, `TODO`/`FIXME`
  comments added in the diff, commented-out code, `.env` or credential-shaped files, stray logs,
  half-renamed symbols, tests that were changed alongside the code (or conspicuously weren't).
- Distinguish staged from unstaged when it matters — if the user has staged a subset, that's a
  signal about what they considered ready.
- Don't claim anything was tested, reviewed, or works. Describe the changes, not their quality.
- Don't suggest next steps unless the user asks — this is a recap. A one-line "looks like the
  remaining piece is X" is fine when it's genuinely obvious from an unfinished change.

## Arguments

If the user passes arguments to `/summarise-changes`, narrow the scope accordingly — e.g. a path
(`/summarise-changes src/Api`) limits the diff to that path, a branch name compares against that
branch instead of the default one.
