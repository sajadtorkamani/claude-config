---
name: request-reviews
description: Get AI reviews on a GitHub PR from every reviewer I use — comments `@codex review` for Codex, requests Copilot as a reviewer, and runs Claude's `/code-review` with its inline comments prefixed `🤖 Claude:` so they're clearly Claude's even though they post under my name. Use when the user runs /request-reviews [pr], asks to get reviews on a PR, or wants the AI reviewers re-run after pushing fixes. Also called by delegate-task.
allowed-tools: AskUserQuestion, Skill, Bash
---

# Request reviews

Put every AI reviewer on a PR in one go, so the user opens it to find Codex, Copilot and Claude
have all had a look. It works on any PR — ones `delegate-task` opened, ones the user opened by
hand — and it's safe to run again after pushing fixes to get a fresh round.

## Step 0 — Find the PR

The PR comes from the arguments: a number (`26`) or a full URL. With no argument, use the current
branch's PR:

```bash
gh pr view [<pr>] --json url,number,headRefName,isDraft,state
```

If there's no PR for the branch, or the PR isn't open, stop and say so — there's nothing to review.
Capture the URL and number; everything below uses them.

## Step 0b — Pick a checkout of the PR for Claude's review

Claude's review takes the diff from GitHub but reads the surrounding code (callers, helpers,
config) from local files. Against the wrong branch it misses bugs and flags code that does exist
on the PR as missing. So pick a checkout that has the PR's code — the first of these that applies
— and call its absolute path the **review dir**. Never switch branches in, or otherwise touch, the
user's current checkout.

1. **The current checkout is on the PR's branch** — `git rev-parse --abbrev-ref HEAD` equals
   `headRefName`. The review dir is `git rev-parse --show-toplevel`.
2. **A worktree already has the branch checked out** (e.g. one `delegate-task` made) — look for
   `branch refs/heads/<headRefName>` in `git worktree list --porcelain`. The review dir is that
   entry's `worktree` path.
3. **Otherwise, create a temporary worktree** at the PR's head commit, outside the repo so it
   never shows up as untracked files. `pull/<number>/head` works for PRs from forks too, and
   `--detach` avoids clashing with a branch of the same name checked out elsewhere:

   ```bash
   git fetch origin "pull/<number>/head"
   REVIEW_DIR="$(mktemp -d)/pr-<number>"
   git worktree add --detach "$REVIEW_DIR" FETCH_HEAD
   ```

   Remember that this run created it — Step 3 removes it when the review finishes.

If the fetch or `worktree add` fails, say so in one line and fall back to the current checkout as
the review dir, noting that Claude's review can only fully trust the diff.

## Step 1 — Codex

Post a comment so the Codex GitHub app reviews the PR:

```bash
gh pr comment <url> --body "@codex review"
```

The body has to be exactly that — the app triggers on the mention, and extra prose around it can
stop it firing. If the comment fails, or the Codex app isn't installed on the repo so nothing reacts
to it, don't retry: say so in one line and move on.

## Step 2 — Copilot

Request Copilot as a reviewer. Automatic Copilot review may skip drafts, so don't rely on it:

```bash
gh pr edit <url> --add-reviewer @copilot
```

On a PR Copilot has already reviewed, this re-requests a review. If it fails (older `gh`, or Copilot
code review not enabled for the repo), don't retry: say so in one line and move on.

## Step 3 — Claude

Run Claude's own review so its findings sit alongside Codex's and Copilot's.

The comments are posted with the user's own GitHub login, so they show up under the user's name.
To make it obvious they came from Claude, every comment this review posts must start with
`🤖 Claude: ` (emoji, the word Claude, a colon, a space).

1. Record the time just before launching, for step 3: `date -u +%Y-%m-%dT%H:%M:%SZ`.
2. Invoke the `code-review` skill (Skill tool, `skill: code-review`) with
   `args: "high --comment <url>"`. Always pass the level explicitly — without one, the review
   reuses whatever level the user last typed, so reviews would get inconsistent depth. The args
   can't carry extra instructions (everything after the level and flags is read as the review
   target), so state both rules in your own words just before invoking it: "Start every comment
   you post on the PR with `🤖 Claude: `. Read the PR's code from `<review dir>`, not the current
   working directory: open files by their absolute paths under it and run git and other commands
   with `cd <review dir> &&` or `git -C <review dir>`." The review runs as a forked background
   agent that inherits this context, so it should see both.
3. The review runs in the background and its result arrives later as a task notification. Don't
   wait for it — report (Step 4) and let the caller carry on. When the notification arrives, make
   sure every comment it posted is prefixed. Fetch the user's comments on the PR created since the
   recorded time — inline review comments, review bodies, and top-level comments:

   ```bash
   ME="$(gh api user -q .login)"
   gh api "repos/{owner}/{repo}/pulls/<number>/comments" --paginate \
     --jq ".[] | select(.user.login == \"$ME\" and .created_at >= \"<since>\") | {id, body}"
   gh api "repos/{owner}/{repo}/pulls/<number>/reviews" --paginate \
     --jq ".[] | select(.user.login == \"$ME\" and .submitted_at >= \"<since>\" and .body != \"\") | {id, body}"
   gh api "repos/{owner}/{repo}/issues/<number>/comments" --paginate \
     --jq ".[] | select(.user.login == \"$ME\" and .created_at >= \"<since>\") | {id, body}"
   ```

   For each one whose body doesn't already start with `🤖 Claude:`, prepend `🤖 Claude: ` and save
   it back — `PATCH repos/{owner}/{repo}/pulls/comments/<id>` for inline comments,
   `PUT repos/{owner}/{repo}/pulls/<number>/reviews/<id>` for review bodies,
   `PATCH repos/{owner}/{repo}/issues/comments/<id>` for top-level comments, each with
   `-f body=<new body>`. Leave any `@codex review` trigger comment alone — editing it can stop
   Codex picking it up. Then tell the user in one line how many findings Claude posted and that
   they're prefixed.
4. If Step 0b created a temporary worktree, remove it now:
   `git worktree remove --force "$REVIEW_DIR"`. Never remove the user's checkout or a worktree
   that already existed.

If the review fails or posts nothing, say so in one line, remove the temporary worktree if there
is one, and move on — don't retry.

## Step 4 — Report

One short line per reviewer: Codex comment posted, Copilot requested, Claude's review running in
the background — or what failed for each. Say which checkout Claude's review is reading (current
checkout, existing worktree, or a temporary one at the PR head).
When called from another skill, keep it to those lines so the caller can fold them into its own
report.

## Rules

- Only add reviewers. Don't approve, merge, change the PR's draft state, labels or description, or
  request review from any human.
- Never check out a branch in the user's current checkout. Only remove the worktree this run created.
- Only edit comments that Claude's review posted in this run. Never edit anyone else's comments, or
  the user's own from before the run.
