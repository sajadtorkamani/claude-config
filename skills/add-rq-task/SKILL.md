---
name: add-rq-task
description: Add a new item to the 'RQ tasks' Notion kanban board with status TODO and my standard task template (DONE / QA / IN PROGRESS / TODO toggles plus a Links list). Use when I run /add-rq-task <title> (e.g. /add-rq-task DEV-103: Look into logout issue) or ask to add an RQ task.
argument-hint: <ticket>: <title>
allowed-tools: mcp__claude_ai_Notion__notion-create-pages, mcp__claude_ai_Notion__notion-search, mcp__claude_ai_Notion__notion-fetch, Bash(open notion://*)
---

# Add an RQ task

Create one page in the **RQ tasks** Notion board.

- Board: https://app.notion.com/p/f5a7f20d8da6418eb987b2bcdcf00d3f
- Data source: `collection://9ecc5786-fba4-4ecb-bd8b-ab7222769edc`

## Steps

1. **Title** — use the skill arguments verbatim as the page title (e.g. `DEV-103: Look into logout issue`).
   If no arguments were given, ask me for the title and don't guess one.
2. **Create the page** with `notion-create-pages`:
   - `parent`: `{"type": "data_source_id", "data_source_id": "9ecc5786-fba4-4ecb-bd8b-ab7222769edc"}`
   - `properties`: `{"Name": "<title>", "Status": "TODO"}`
   - `content` (copy exactly, it's the template):

     ```
     <empty-block/>
     <details>
     <summary>DONE</summary>
     </details>
     <details>
     <summary>QA</summary>
     </details>
     <details>
     <summary>IN PROGRESS</summary>
     </details>
     <details>
     <summary>TODO</summary>
     	- [ ] Go through QA items
     </details>
     - Links
     	- Jira issue
     ```

     (The `- [ ]` and nested `- Jira issue` lines are indented with a single tab.)
   - `allow_async`: `false`, so the page URL comes back straight away.
3. **Open it in the Notion app** — take the 32-character page ID from the returned URL
   (the part after `/p/`, without `?pvs=...`) and run:

   ```bash
   open "notion://www.notion.so/<page-id>"
   ```

   This focuses the Notion desktop app if it's running, or launches it, and navigates to the page.
   If the command fails (e.g. Notion isn't installed), just mention it and carry on.
4. **Report** — reply with one line: the title and a link to the new page.

## If it fails

- If the data source can't be found, the Notion connector is probably linked to a different
  workspace. Say so and ask me to switch it, rather than creating the board or the page somewhere else.
- If the `Status` options have changed (no `TODO` option), fetch the data source, tell me what the
  options are now, and ask which one to use.
