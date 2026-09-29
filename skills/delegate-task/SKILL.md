---
name: delegate-task
description: Take a task end to end in an isolated git worktree and hand back a draft PR — does the work, commits, pushes, opens a draft PR into the branch you choose, assigns it to you, requests you as reviewer, labels it `claude` and `needs-review`, asks Codex and Copilot to review it, and writes the PR description. Use whenever the user runs /delegate-task, or asks you to do a piece of work "in a worktree" and open a PR for it, or says to go off and build something and come back with a PR to review.
allowed-tools: AskUserQuestion, Skill, EnterWorktree, ExitWorktree, TodoWrite, Read, Write, Edit, Glob, Grep, Bash
---

# Delegate task

Take a task from a one-line description to a draft PR sitting in the user's review queue, doing
the work in a throwaway worktree so their main checkout is never touched.

The whole point is that the user hands off a task and gets back something reviewable. Two things
follow from that: their working tree must come out exactly as it went in, and the PR must arrive
fully dressed — draft, assigned, reviewer requested, labelled, described, Codex and Copilot asked
to review —
so there's nothing left for them to click.

## Step 0 — Know the task

The task comes from the `/delegate-task` arguments, or from what the user just asked for in
conversation. If neither gives you something concrete enough to build, ask what they want before
touching anything — a worktree created for a misunderstood task is wasted work.

If the task depends on uncommitted changes in the current checkout, stop and say so. The worktree
starts from a clean remote branch, so that work would not come along. Suggest committing (or
stashing and re-applying) first, and let the user decide.

## Step 1 — Work out the base branch

The base is **not** fixed — the user merges into `staging`, `pre-prod`, `main` and others depending
on the work. Never assume one. It matters here more than in a normal PR skill, because the worktree
branch has to be cut from the base; getting it wrong means the PR diff is full of unrelated commits.

If the arguments name a base (e.g. `/delegate-task fix the date picker, into pre-prod`), use it.
Otherwise gather candidates in parallel (read-only; ignore any that fail):

- `git rev-parse --abbrev-ref HEAD` — current branch.
- `git symbolic-ref --short refs/remotes/origin/HEAD` — remote default branch.
- `git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin` — to spot
  `staging`, `pre-prod`, `develop`, release branches.
- `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` — fallback for the default.

Ask with **one** `AskUserQuestion` call:

- Question: "Which branch should this PR merge into?"
- Header: `Base branch`.
- Options: the 2–4 most likely bases, best guess first with "(Recommended)". The branch the user is
  currently on is usually a good guess for where similar work lands. Anything else via "Other".

Ask this **before** creating the worktree. Everything downstream depends on the answer.

## Step 2 — Create the worktree

Call `EnterWorktree` with a descriptive name derived from the task (e.g. `fix-date-picker`), not a
random one — the user will see this directory and branch name later.

The worktree's base ref is governed by the `worktree.baseRef` setting, which usually branches from
the repo's **default** branch. If the chosen base is anything else, re-point the branch before
writing a line of code, while the worktree is still empty and this is free:

```bash
git fetch origin <BASE>
git reset --hard origin/<BASE>
```

Confirm with `git log --oneline -1` that HEAD is now the tip of the base.

Then get the worktree actually usable. A fresh worktree has no gitignored files, so anything the
project needs but doesn't track is missing — `.env` files, `node_modules`, `vendor`, local config.
Check what the project expects (`.env.example`, the README, lockfiles) and set it up:

- Copy env files across from the main checkout (`cp <main-checkout>/.env .env`) — these are
  gitignored, so this is the only way they get there.
- Install dependencies if the task needs to build, lint, or run tests (`npm ci`, `composer install`).
  Skip it for a change you can verify by reading alone; it's slow and often unnecessary.

If you can't get the project into a runnable state, carry on with the work but say so in the report
— an unverified change is fine as long as the user knows it's unverified.

## Step 3 — Do the work

Build the thing. This is ordinary work, with the usual expectations: follow the repo's conventions
and CLAUDE.md, match the surrounding code, and verify what you reasonably can (types, lint, the
relevant tests) rather than declaring it done on inspection.

A few things specific to being delegated:

- **Stay inside the task.** The user isn't watching closely and will review a diff, so unrequested
  refactors and drive-by fixes cost them review time they didn't agree to.
- **Don't stop early to ask.** If a decision is genuinely ambiguous, pick the most defensible option,
  note the assumption, and flag it in the PR description under "Notes" — that's what the draft
  status is for. Only stop if proceeding either way would be unsafe or make the work useless.
- **If the task turns out to be blocked or wrong-headed**, do every part you can, and say plainly in
  the report and the PR what you left out and why. Scaling the task down isn't your call.

## Step 4 — Commit and push

Invoke the `commit` skill (Skill tool, `skill: commit`) — it handles message style, ticket prefixes,
and splitting logical changes. Then push:

```bash
git push -u origin HEAD
```

If the push is rejected, stop and report it; don't force-push.

## Step 5 — Write the PR description

Invoke the `pr-summary` skill (Skill tool, `skill: pr-summary`), passing the base branch as the
argument so it doesn't ask again. Write its markdown output to a file rather than pasting it into a
shell argument — PR bodies contain backticks, quotes and newlines that don't survive the round trip:

```bash
cat > "<scratchpad>/delegate-task/pr-body.md" <<'EOF'
<the markdown from pr-summary>
EOF
```

Use the session's scratchpad directory if it lists one, otherwise `${TMPDIR:-/tmp}`.

Add anything the user should know before reviewing: assumptions you made, parts of the task you
couldn't do, whether you were able to run the tests.

## Step 6 — Open the PR

Create it as a draft, then dress it up in separate steps. Doing it all in one `gh pr create` means a
missing label or a rejected reviewer takes the whole PR down with it:

```bash
gh pr create --draft \
  --base "<BASE>" \
  --title "<title>" \
  --body-file "<scratchpad>/delegate-task/pr-body.md" \
  --assignee @me
```

Use the same title convention as the commit (ticket prefix etc.). Capture the PR URL it prints.

Then, each as its own command so one failure doesn't block the rest:

- **Labels** — `gh pr edit <url> --add-label claude --add-label needs-review`. GitHub rejects the
  whole call if either label is missing from the repo, so on failure create the missing ones and
  retry once:

  ```bash
  gh label create claude --color D93F0B --description "Opened by Claude"
  gh label create needs-review --color FBCA04 --description "Waiting on review"
  ```

  A label that already exists makes `gh label create` fail — that's fine, ignore it and retry the
  `gh pr edit`.
- **Reviewer** — `--add-reviewer` takes a literal login and does not understand `@me`, so resolve
  it first: `gh pr edit <url> --add-reviewer "$(gh api user -q .login)"`. GitHub refuses to request
  a review from the PR's own author, so when the user's own token opened the PR this returns
  "Review cannot be requested from pull request author". That's expected, not a bug: mention it in
  one line in the report and move on. The PR is already assigned to them, which is what actually
  puts it on their dashboard.
- **Codex review** — post a comment on the PR so the Codex GitHub app picks it up and reviews the
  diff before the user does:

  ```bash
  gh pr comment <url> --body "@codex review"
  ```

  The body has to be exactly that — the app triggers on the mention, and extra prose around it can
  stop it firing. If the comment fails, or the Codex app isn't installed on the repo so nothing
  reacts to it, that's not worth retrying: say so in one line in the report and move on.
- **Copilot review** — request Copilot as a reviewer so it reviews the draft too (automatic
  Copilot review may skip drafts, so don't rely on it):

  ```bash
  gh pr edit <url> --add-reviewer @copilot
  ```

  If it fails (older `gh`, or Copilot code review not enabled for the repo), don't retry: say so
  in one line in the report and move on.

Verify the end state with `gh pr view <url> --json isDraft,assignees,reviewRequests,labels` so the
report reflects what GitHub actually has, not what you asked for.

## Step 7 — Hand back

Leave the worktree with `ExitWorktree` (`action: "keep"`) so the branch and directory survive for
follow-up work while the session returns to the main checkout.

Then report, briefly:

- The PR URL and title, and that it's a draft.
- Base branch and commit count.
- Which of assignee / reviewer / label / Codex comment / Copilot review actually stuck, and
  anything that didn't.
- What you verified (tests run, types checked) and what you couldn't.
- Any assumptions or unfinished parts — repeat them here even though they're in the PR body; this is
  the bit the user reads first.
- The worktree path and branch name, so they can jump back in.

Keep it short. The PR description carries the detail.

## Rules

- Never touch the user's original checkout — no commits, no branch switches, no stashing there. The
  only reason to read from it is copying gitignored config into the worktree.
- Never force-push, and never mark the PR ready for review — it stays a draft until the user says
  otherwise.
- Don't merge, don't request review from any human but the user, and don't add labels beyond
  `claude` and `needs-review` unless asked. The `@codex review` comment and the Copilot review
  request are the exceptions — they go on every delegated PR.
- No Claude attribution or co-author trailers in commits or the PR body.
- If the work fails partway, still report where things stand and leave the worktree in place —
  half-finished work the user can inspect beats a silent rollback.
