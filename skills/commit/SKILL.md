---
name: commit
description: Commit the current changes with a concise summary title (≤72 chars) and an optional description body for extra detail. Use when the user runs /commit or asks to commit their changes.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
---

# Commit

Create a git commit for the current changes.

## Steps

1. Gather context (run in parallel):
   - `git status`
   - `git diff --staged` and `git diff`
   - `git log --oneline -10` (to match the repo's existing message style, e.g. `feat(TICKET): ...` prefixes)

2. Decide what to commit:
   - If files are already staged, commit only what's staged.
   - If nothing is staged, stage the relevant changed files by name (`git add <paths>`). Avoid `git add -A` / `git add .`.
   - Never stage files that likely contain secrets (`.env`, credentials, keys). Warn the user if such files are changed.
   - If there are no changes, say so and stop.

3. Write the commit message:
   - **Title**: a summary of the changes in the imperative mood (e.g. "Add retry logic to webhook handler").
     - Hard limit of **72 characters** so it isn't truncated on GitHub; aim for ~50.
     - No trailing period.
     - Follow the repo's existing conventions (prefixes, ticket IDs) if the log shows a consistent pattern. If the branch name contains a ticket ID (e.g. `DEV-123`) and the repo uses them, include it.
   - **Description** (only if there's more worth saying): leave a blank line after the title, then explain *what* changed and *why* — notable details, trade-offs, side effects, or a short bullet list of changes. Wrap lines at ~72 chars. Don't restate the title or narrate the diff line by line.
   - If the title fully captures a small change, omit the description.

4. Commit using a heredoc so formatting is preserved:

   ```bash
   git commit -m "$(cat <<'EOF'
   Title goes here

   Optional description goes here.
   EOF
   )"
   ```

   Include any commit attribution lines required by the current session's instructions at the end of the message.

5. Run `git status` to confirm the commit succeeded, then report the commit title (and hash) to the user.

## Rules

- Don't push unless the user asks.
- Don't amend, skip hooks (`--no-verify`), or change git config.
- If a pre-commit hook fails, fix the issue if straightforward and create a **new** commit attempt; otherwise report the failure.
- If the user passes arguments to /commit (e.g. extra context or a desired message), take them into account.
