---
name: review-handoff
description: Prepare the current branch's changes for review by another agentic coding CLI (Codex, Gemini CLI, a fresh Claude Code session, etc.) - asks which base branch the work merges into, then writes a short review prompt the other agent can run in the same checkout. Also covers triaging the findings the user pastes back. Use when the user runs /review-handoff or asks to hand changes off to another model for review.
allowed-tools: AskUserQuestion, Write, Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git symbolic-ref:*), Bash(git merge-base:*), Bash(git fetch:*), Bash(git remote:*), Bash(git for-each-ref:*), Bash(pbcopy:*)
---

# Review handoff

Write a review prompt for the current branch's changes that another agentic CLI (Codex CLI,
Gemini CLI, a fresh Claude Code session, ...) can run in the same checkout, and make its findings
easy to bring back here for verification.

The reviewer reads the repo itself, so the prompt only states the diff range, intent, focus and
output format. Don't paste diffs or file contents into it - that wastes tokens on both sides.

**Ask first, write second.** Don't read the diff or write the prompt until the base branch is known.

## Step 1 - Work out the base branch

The base is **not** fixed - the user merges into `staging`, `pre-prod`, or other branches
depending on the work. Never assume one.

If the `/review-handoff` arguments name a base branch (e.g. `/review-handoff pre-prod`), use it and
skip to step 2. Also accept a commit range or single commit (`abc123..HEAD`, `HEAD~3`,
`abc123`) - if given, use that range verbatim and skip the question.

Otherwise, gather candidates in parallel (read-only; ignore any that fail):

- `git rev-parse --abbrev-ref HEAD` - current branch.
- `git rev-parse --abbrev-ref --symbolic-full-name @{upstream}` - upstream, if any.
- `git symbolic-ref --short refs/remotes/origin/HEAD` - remote default branch.
- `git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin` - branch list, to
  spot `staging`, `pre-prod`, `main`, `develop`, release branches.
- For each plausible base (up to ~5), count commits ahead:
  `git rev-list --count "$(git merge-base <base> HEAD)"..HEAD`.
  The base with the **fewest** commits ahead (but more than zero) is usually the branch this one was
  cut from - rank it first.

Ask with **one** `AskUserQuestion` call:

- Question: "Which branch will this work merge into?"
- Header: `Base branch`.
- Options: 2-4 most likely bases, best guess first with "(Recommended)". In each description give
  the commits-ahead count. The user can type any other branch via "Other".

If the current branch *is* one of the candidate bases (e.g. the user is on `staging`), say so and
ask whether they meant the uncommitted changes only, or a specific commit range.

## Step 2 - Resolve the range

With the chosen base `BASE`:

- `git fetch origin BASE` if it has a remote counterpart; if it fails, carry on and note the base
  may be stale. Prefer `origin/BASE` over a local `BASE` when the remote one is newer.
- `MERGE_BASE=$(git merge-base <base-ref> HEAD)`; the review range is `MERGE_BASE..HEAD`.
- Check `git status --porcelain`. If there are uncommitted changes, tell the user and ask whether to
  include them (the reviewer then runs `git diff MERGE_BASE` against the working tree) or review
  committed work only. Recommend committing first - it stops the code shifting under the review.
- If the range is empty, say so and stop.

## Step 3 - Understand the change

- `git log --no-merges --pretty='%h %s%n%b' MERGE_BASE..HEAD`
- `git diff --stat MERGE_BASE..HEAD`
- Only read the actual diff if the log and stat aren't enough to write an accurate intent summary
  and pick focus areas. If this conversation already did the work, use that knowledge instead.

## Step 4 - Write the prompt

Path: `<scratchpad>/review-handoff/<repo>-<branch-slug>/prompt.md` when the session lists a
scratchpad directory, otherwise `${TMPDIR:-/tmp}/review-handoff/<repo>-<branch-slug>/prompt.md`.
Overwrite any existing file.

```markdown
Review the changes on branch `<branch>` against `<BASE>`:

    git diff <MERGE_BASE_SHORT>..HEAD      # merge base with <BASE>
    git log --oneline <MERGE_BASE_SHORT>..HEAD

Read the surrounding code and call sites as needed, not just the diff.

## Intent

<2-4 sentences: what the change is for and the approach taken. Mention anything deliberately
out of scope so the reviewer doesn't flag it.>

## Focus on

- Correctness bugs: wrong logic, missed edge cases, broken existing behaviour.
- <project-specific risks picked from the diff, e.g. security/permission expressions, tenant or
  company scoping, migration/data safety, serialization groups, API contract changes>
- Missing or weak tests for the changed behaviour.

## Ignore

- Style, naming and formatting preferences, unless they break a rule in the repo's
  <rules files>.
- Pre-existing issues in unchanged code, unless the change makes them worse.

## Output format

For each finding:

- **Severity**: high / medium / low
- **Location**: file:line
- **Problem**: one sentence
- **Failure scenario**: concrete input/state -> wrong result
- **Suggested fix**

Rank most severe first. If you find nothing real, say "No issues found" - don't pad the list.
Do not edit any files.
```

Fill the focus bullets from what the diff actually touches; drop generic ones that don't apply.
For `<rules files>`, list only the ones that exist (AGENTS.md, CLAUDE.md, `.claude/rules/*`); drop
the clause if there are none. If uncommitted changes are included, swap the diff command for
`git diff <MERGE_BASE_SHORT>`.

## Step 5 - Report

- Copy the prompt to the clipboard with `pbcopy < .../prompt.md` (skip silently if unavailable).
- Tell the user, briefly: base branch and merge-base SHA, commit count, and the file path.
- One-line reminder: start the other CLI in this repo, paste the prompt (already on the
  clipboard), then paste its findings back here.

## When the findings come back

When the user pastes another model's review (this may be a later turn, or a later session):

- **Verify every finding against the actual code before changing anything.** Open the file, trace
  the scenario, and classify each as **Real** (fix), **Not a bug** (explain why, briefly), or
  **Judgement call** (user decides).
- If several reviewers' outputs are pasted, dedupe them and note where they disagree.
- Present the triage as a compact list, then ask before applying fixes unless the user already said
  to fix the real ones.

## Rules

- Read-only on the repo: never commit, push, stash, change branches, or edit repo files as part of
  the handoff. The only file written is the prompt.
- No Claude attribution in the generated prompt.
- Use plain ASCII punctuation in the generated prompt.
