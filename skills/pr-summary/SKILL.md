---
name: pr-summary
description: Ask which base branch the PR targets and which PRs it relates to, then summarise the branch's commits as markdown ready to paste into the GitHub PR description. Use when the user runs /pr-summary or asks for a PR description/summary.
allowed-tools: AskUserQuestion, Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(git merge-base:*), Bash(git fetch:*), Bash(git remote:*), Bash(gh repo view:*), Bash(gh pr list:*), Bash(gh pr view:*)
---

# PR summary

Produce a markdown PR description for the current branch, based on its commits, that the user can
paste straight into the GitHub PR page.

**Ask first, summarise second.** Steps 1–2 gather the base branch and any related PRs from the
user. Don't start reading commits or drafting until those answers are in.

## Step 1 — Gather options for the questions

Run these in parallel (all are read-only; ignore any that fail):

- `git rev-parse --abbrev-ref HEAD` — the current branch.
- `git symbolic-ref --short refs/remotes/origin/HEAD` — the remote's default branch
  (falls back to `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`).
- `git branch --format='%(refname:short)'` — local branches, to spot `develop`, `staging`, release
  branches etc.
- `gh pr list --state open --limit 10 --json number,title,headRefName,author` — open PRs that could
  be related (skip silently if `gh` isn't available or authenticated).

If the current branch **is** the default branch, say so and ask the user which branch they actually
want summarised before going further — a PR from `main` into `main` is almost certainly not what
they meant.

## Step 2 — Ask the user

Use **one** `AskUserQuestion` call with both questions (the user answers them together):

1. **Base branch** — "Which branch should this PR merge into?"
   - Header: `Base branch`.
   - Options: the repo's default branch first (label it "(Recommended)" when it's the obvious
     target), then any other plausible bases found in step 1 (`develop`, `staging`, a release
     branch, the branch this one was cut from). Keep it to the 2–4 most likely; the user can type
     anything else via "Other".
   - In each option's description, mention the commit count ahead of that base if you have it.

2. **Related PRs** — "Any related PRs to link?"
   - Header: `Related PRs`.
   - `multiSelect: true`.
   - Options: "None" first, then up to three open PRs from step 1, labelled `#123 Title`.
   - The user can type PR numbers, URLs, or issue references via "Other". If `gh pr list` returned
     nothing, still ask — offer "None" and let them type references.

Don't invent a third question. If the user's `/pr-summary` arguments already state the base branch
and/or related PRs, skip the corresponding question (ask only what's still unknown, or nothing at
all if both are covered).

## Step 3 — Read the branch's changes

With the chosen base (call it `BASE`):

- `git fetch origin BASE` if `BASE` has a remote counterpart, so the comparison isn't stale. Skip
  it silently if the fetch fails (offline, no remote) and note that the base may be out of date.
- Use the merge base, not the branch tip, so the summary covers only this branch's work:

  ```bash
  git log --no-merges --pretty='%h %s%n%b' "$(git merge-base BASE HEAD)"..HEAD
  git diff --stat "$(git merge-base BASE HEAD)"..HEAD
  ```

- If the commit subjects are terse or the diffstat shows something the log doesn't explain, read
  the actual diff (`git diff <merge-base>..HEAD -- <paths>`) for the files that matter. The summary
  should describe *what changed*, not just re-list commit titles.
- If there are no commits between the base and HEAD, say so and stop — there's nothing to
  summarise.

## Step 4 — Write the summary

Output the description inside a fenced ` ```markdown ` block so the user can copy it in one go.
Put nothing else inside the fence — no preamble, no "here's your summary".

Shape it roughly like this, dropping any section that would be empty:

```markdown
## Summary

One or two sentences on what this PR does and why.

## Changes

- **Area / file group** — what changed and the reason.
- **Another area** — …

## Notes

Anything a reviewer needs: migrations, config or env changes, follow-up work, trade-offs,
breaking changes.

## Related

- Depends on #123
- Related to #456
```

Guidelines:

- **Group by change, not by commit.** Several commits touching the same thing become one bullet;
  a single commit doing three unrelated things becomes three.
- Write for a reviewer who hasn't seen the branch: what changed, why, and what to look at.
- Skip noise — formatting-only commits, merge commits, "fix typo", WIP commits squashed into
  later work. Mention them only if they're the substance of the PR.
- Keep it proportionate: a three-commit branch gets a short summary and a few bullets, not a
  templated wall of headings.
- Don't claim the code was tested, reviewed, or deployed. Only mention tests if the branch
  actually adds or changes them.
- Use the repo's existing PR conventions if they're visible (`gh pr view` on a recent merged PR)
  — ticket prefixes, checklists, a required template.
- If the repo has a `.github/pull_request_template.md`, follow its structure instead of the one
  above, filling in each section from the commits.

**Related PRs**: render the user's answer as a `## Related` section. Bare numbers become `#123`;
URLs stay as URLs. If they picked "None", omit the section entirely. Don't guess at relationships
the user didn't state — if they gave a number without context, use a neutral "Related to #123".

## Step 5 — Report

After the fenced block, add a short line outside it: the base branch, the number of commits
summarised, and the "create PR" URL if you have one
(`gh repo view --json url -q .url` + `/compare/BASE...HEAD?expand=1`).

## Rules

- Read-only. Never create the PR, push, commit, or change branches — this skill only drafts text.
  If the user wants the PR opened, tell them to run `gh pr create` (or offer to, and wait for a yes).
- Never fabricate ticket numbers, issue links, or reviewers.
- Don't add attribution or "Generated with Claude Code" trailers to the summary — it's the user's
  PR description.
