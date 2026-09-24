---
name: add-wiki-note
description: Create a new note in the wiki (~/code/wiki) — asks for a title and a category, then writes docs/<category>/<slug>.md with the title as its H1 and regenerates the index pages. Use when the user runs /add-wiki-note or asks to add/create a wiki note or page.
allowed-tools: AskUserQuestion, Read, Write, Bash(ls:*), Bash(git status:*), Bash(git rev-parse:*), Bash(python3 .artifacts/build_index.py), Bash(npm run format:*)
---

# Add a wiki note

Create a new markdown note in the wiki from two things the user gives you: a **title** and a
**category**.

## Step 0 — Find the wiki

The wiki lives at `~/code/wiki` (a repo whose root has `mkdocs.yml` and a `docs/` directory). If
the current working directory is already that repo, use it; otherwise use `~/code/wiki`. If
neither exists, say so and stop — don't create a wiki somewhere else.

All paths below are relative to that repo root.

## Step 1 — Get the title

If the user passed arguments to `/add-wiki-note`, treat them as the title (and don't ask again).

Otherwise ask for it in plain text — a title is free text, so `AskUserQuestion` only gets in the
way here:

> What's the title of the note?

Wait for their answer before going further.

## Step 2 — Get the category

List the existing categories with `ls docs`, then ask with **one** `AskUserQuestion` call:

- Question: "Which category should this note go in?"
- Header: `Category`
- Options: up to 4 existing categories that plausibly fit the title (most likely first), each
  described with roughly how many notes it already holds. The user types anything else — including
  a brand new category — via "Other".

If the user's `/add-wiki-note` arguments already named the category (e.g. `JetBrains: pin a tab`),
skip the question.

Normalise whatever they give you into a folder name: **lowercase it, and replace each space with a
hyphen**. `JetBrains` → `jetbrains`, `Data structures` → `data-structures`.

Then check the normalised name against `ls docs`:

- It matches an existing folder → use it.
- It doesn't → tell the user you're creating a new category folder, and check first whether a close
  sibling already exists (`docker` vs `docker-recipes`, `css` vs `css-recipes`). A typo'd category
  creates an orphan folder that shows up in the nav, so it's worth a second of care.

## Step 3 — Work out the filename

Slugify the title:

1. Lowercase it.
2. Drop apostrophes entirely (`Don't` → `dont`).
3. Replace every remaining run of non-alphanumeric characters with a single hyphen — spaces,
   colons, slashes, brackets, ampersands and the rest.
4. Trim leading and trailing hyphens.

`Datagrip: How to add a MySQL procedure/routine` → `datagrip-how-to-add-a-mysql-procedure-routine`.

The file is `docs/<category>/<slug>.md`.

If that file already exists, **stop and ask** rather than overwriting — offer to open the existing
note instead, or to use a different title.

## Step 4 — Write the file

The body is just the title as an H1, with the user's capitalisation preserved exactly as typed:

```markdown
# Title exactly as the user typed it
```

Then a trailing newline. No frontmatter — the wiki has none, and the first H1 is what becomes the
page title and the sidebar entry.

If the user's arguments included content for the note (not just a title), write that under the H1
as well. Otherwise leave the file at the H1 alone — the user writes the note themselves.

## Step 5 — Regenerate the indexes and format

Both are required; CI fails the build without them.

```bash
python3 .artifacts/build_index.py
npm run format
```

`build_index.py` rewrites `docs/index.md` and every `docs/<category>/index.md`, so a brand new
category gets its landing page and the new note appears in its category index.

## Step 6 — Report

Tell the user:

- the path of the new file, as a clickable `docs/<category>/<slug>.md`,
- that it's a new category, if it is,
- and nothing else. Don't commit, don't push, don't start `bin/dev` — the user writes the note
  next, and commits when they're ready.

## Rules

- One note per run. If the user asks for several, create them all, but ask for a title and category
  for each.
- Never overwrite an existing note.
- Don't invent content for the note. The H1 is the deliverable; the prose is the user's.
- Don't edit `mkdocs.yml` — the nav is built from the directory tree by the `awesome-nav` plugin.
