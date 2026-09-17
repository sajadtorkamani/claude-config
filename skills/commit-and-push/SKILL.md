---
name: commit-and-push
description: Commit the current changes (via the commit skill) and then push them to the remote. Use when the user runs /commit-and-push or asks to commit and push their changes.
allowed-tools: Skill, Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git rev-parse:*), Bash(git remote:*), Bash(gh:*)
---

# Commit and push

Commit the current changes, then push them to the remote.

## Steps

1. **Commit** — invoke the `commit` skill (Skill tool, `skill: commit`), forwarding any
   arguments passed to `/commit-and-push`. Follow it exactly: it decides what to stage and
   writes the message.
   - If it reports there was nothing to commit, check whether the branch already has unpushed
     commits (`git status -sb` or `git log @{u}.. --oneline`). If it does, continue to the push;
     otherwise say there's nothing to do and stop.
   - If the commit fails (e.g. a pre-commit hook), do **not** push. Report the failure.
   - The commit skill prints its own branch URL with a "not pushed yet" caveat. Ignore it here —
     step 4 prints the authoritative link after the push.

2. **Check the remote** — confirm there is somewhere to push to:
   - `git remote -v`. If there's no remote, tell the user and stop (offer `gh repo create` rather
     than running it unprompted).
   - If `gh` is the auth path for this repo and the push later fails on credentials, check
     `gh auth status` and report what it says.

3. **Push**:

   ```bash
   git push -u origin HEAD
   ```

   - `-u origin HEAD` pushes the current branch and sets upstream on first push; it's a no-op
     for branches that already track a remote.
   - Never use `--force` or `--force-with-lease` unless the user explicitly asks for it.
   - If the push is rejected as non-fast-forward, stop and report it. Suggest `git pull --rebase`
     — don't run it or force-push on your own.

4. **Link the branch** — print a clickable GitHub URL for the branch that was just pushed:

   ```bash
   gh browse -n -b "$(git rev-parse --abbrev-ref HEAD)"
   ```

   - `-n` prints the URL instead of opening a browser.
   - Skip it silently if there's no GitHub remote or `gh` isn't available/authenticated — the
     push still succeeded.

5. **Report** — give the user the commit title and hash, the branch, confirmation that the push
   succeeded, and the branch URL from step 4. If the push output includes a link (e.g. a
   "create a pull request" URL), pass that along too.

## Rules

- Commit first, push second — never push without a successful commit step.
- Don't open a pull request unless the user asks. If they do, use `gh pr create`.
- Don't amend, skip hooks (`--no-verify`), or change git config.
- Pushing is outward-facing and hard to undo: if the current branch is the repo's default branch
  and the user hasn't clearly asked to push to it, confirm before pushing.
