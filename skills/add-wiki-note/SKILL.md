---
name: add-wiki-note
description: Create a new note in the wiki (~/code/wiki) — takes a title and a category (as arguments or by asking), writes docs/<category>/<slug>.md with the title as its H1, regenerates the index pages and opens the note in PhpStorm. Use when the user runs /add-wiki-note or asks to add/create a wiki note or page.
allowed-tools: AskUserQuestion, Read, Write, Bash(ls:*), Bash(git status:*), Bash(git rev-parse:*), Bash(python3 .artifacts/build_index.py), Bash(npm run format:*), Bash(phpstorm:*), Bash(command -v:*)
---

# Add a wiki note

Create a new markdown note in the wiki from two things the user gives you: a **title** and a
**category**.

## Step 0 — Find the wiki

The wiki lives at `~/code/wiki` (a repo whose root has `mkdocs.yml` and a `docs/` directory). If
the current working directory is already that repo, use it; otherwise use `~/code/wiki`. If
neither exists, say so and stop — don't create a wiki somewhere else.

All paths below are relative to that repo root.

## Step 1 — Read the arguments

The command takes the title first, then the category:

```
/add-wiki-note "Jetbrains shortcuts" jetbrains
```

Parse whatever the user passed:

- **Quoted title followed by a bare word** → that's the title and the category. Ask nothing; go
  straight to Step 4.
- **Quoted title alone** → title given, category still needed (Step 3).
- **Unquoted arguments** → treat the whole string as the title, and don't try to guess a trailing
  category out of it. A title is free text and "shortcuts" is as plausibly the last word of a title
  as it is a folder name.
- **No arguments** → ask for the title (Step 2), then the category (Step 3).

## Step 2 — Get the title

Only if the arguments didn't supply one. Ask in plain text — a title is free text, so
`AskUserQuestion` only gets in the way here:

> What's the title of the note?

Wait for their answer before going further.

## Step 3 — Get the category

Only if the arguments didn't supply one. List the existing categories with `ls docs`, then ask with
**one** `AskUserQuestion` call:

- Question: "Which category should this note go in?"
- Header: `Category`
- Options: up to 4 existing categories that plausibly fit the title (most likely first), each
  described with roughly how many notes it already holds. The user types anything else — including
  a brand new category — via "Other".

## Step 4 — Normalise the category

Whether it came from the arguments or the question, normalise it into a folder name: **lowercase
it, and replace each space with a hyphen**. `JetBrains` → `jetbrains`, `Data structures` →
`data-structures`.

Then check the normalised name against `ls docs`:

- It matches an existing folder → use it.
- It doesn't → tell the user you're creating a new category folder, and check first whether a close
  sibling already exists (`docker` vs `docker-recipes`, `css` vs `css-recipes`). A typo'd category
  creates an orphan folder that shows up in the nav, so it's worth a second of care. This matters
  more when the category came from the arguments, since nothing has confirmed it against the list.

## Step 5 — Work out the filename

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

## Step 6 — Write the file

The body is just the title as an H1, with the user's capitalisation preserved exactly as typed:

```markdown
# Title exactly as the user typed it
```

Then a trailing newline. No frontmatter — the wiki has none, and the first H1 is what becomes the
page title and the sidebar entry.

If the user's arguments included content for the note (not just a title), write that under the H1
as well. Otherwise leave the file at the H1 alone — the user writes the note themselves.

## Step 7 — Regenerate the indexes and format

Both are required; CI fails the build without them.

```bash
python3 .artifacts/build_index.py
npm run format
```

`build_index.py` rewrites `docs/index.md` and every `docs/<category>/index.md`, so a brand new
category gets its landing page and the new note appears in its category index.

## Step 8 — Open the note in PhpStorm

The user writes the note next, so open it for them — after the formatting step, so the file on disk
is final:

```bash
phpstorm docs/<category>/<slug>.md
```

That's the JetBrains Toolbox launcher; it reuses the running PhpStorm instance. If the command
isn't on `PATH` (`command -v phpstorm`), skip this step and say so in the report — the note is
already written, so a missing launcher is a footnote, not a failure.

## Step 9 — Report

Tell the user:

- the path of the new file, as a clickable `docs/<category>/<slug>.md`,
- that it's a new category, if it is,
- that it's open in PhpStorm (or that the launcher wasn't found),
- and nothing else. Don't commit, don't push, don't start `bin/dev` — the user writes the note
  next, and commits when they're ready.

## Rules

- One note per run. If the user asks for several, create them all, but ask for a title and category
  for each.
- Never overwrite an existing note.
- Don't invent content for the note. The H1 is the deliverable; the prose is the user's.
- Don't edit `mkdocs.yml` — the nav is built from the directory tree by the `awesome-nav` plugin.
