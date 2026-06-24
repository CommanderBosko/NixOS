---
name: save-memory
description: Triggers when user says "save a memory", "remember this", "write a memory", "save to memory", "add a memory", or "note this for next time". Writes one well-formed memory file (correct frontmatter + body) to the project memory dir and adds its one-line pointer to MEMORY.md.
version: 0.2.0
---

# Save Memory

Persist a single fact as one memory file in this project's memory store, with valid frontmatter, and register it in the `MEMORY.md` index. One file = one fact. Do not pack multiple unrelated facts into one file.

(Bucket: Utility — write one memory file plus its index line, every time.)

Memory dir: `/home/bosko/.claude/projects/-home-bosko-NixOS/memory/`
Index file: `/home/bosko/.claude/projects/-home-bosko-NixOS/memory/MEMORY.md`

## Step 1 — Establish the fact and its type

Pin down the single fact to store and classify its `type`:

- **user** — who the user is (role, expertise, preferences).
- **feedback** — guidance on how you should work (corrections or confirmed approaches). Body must include a **Why:** line.
- **project** — ongoing work, goals, or constraints not derivable from code or git history. Body must include **Why:** and **How to apply:** lines, and convert any relative dates ("today", "next week") to absolute YYYY-MM-DD.
- **reference** — pointers to external resources (URLs, dashboards, tickets).

Do **not** save what the repo already records (code structure, past fixes, git history, CLAUDE.md) or what only matters to the current conversation. If asked to remember one of those, ask what was non-obvious about it and save that instead.

## Step 2 — Check for an existing memory to update

List the memory dir and read `MEMORY.md` to see if a file already covers this fact:

```bash
ls /home/bosko/.claude/projects/-home-bosko-NixOS/memory/
```

If one does, **update that file** instead of creating a duplicate. If a memory turns out to be wrong, delete it rather than stacking a contradicting one.

## Step 3 — Derive the slug and write the file

Pick a short kebab-case `name` slug. The filename convention in this dir is `<type>_<slug>.md` (e.g. `project_vpn_setup.md`, `feedback_use_dry_run_skill.md`) — match the existing naming.

Read `assets/memory-template.md` and write `<dir>/<type>_<slug>.md` from it, substituting `<kebab-case-slug>`, the `description`, the `type`, and the body. Drop the trailing HTML-comment block (it only documents the index line for Step 4). For feedback, follow the fact with a **Why:** line; for project, follow with **Why:** and **How to apply:** lines.

Link liberally to related memories with `[[slug]]` — a link whose target doesn't exist yet is fine; it marks something worth writing later.

## Step 4 — Add the index pointer to MEMORY.md

Append (or update, if revising an existing memory) a single line under the index in `MEMORY.md`, using the index-line format documented in `assets/memory-template.md`:

```
- [Title](<type>_<slug>.md) — <short hook of why it matters>
```

One line per memory. Never put memory body content in `MEMORY.md` — it is only an index.

## Step 5 — Confirm

Tell the user the filename written, its `type`, and the one-line index hook added. If you updated an existing memory instead of creating one, say which file and what changed.

---

## Key constraints

- One fact per file. Split multiple facts into multiple `save-memory` writes.
- Always classify the `type` correctly — it drives the required body lines (Why / How to apply).
- Convert relative dates to absolute (YYYY-MM-DD) before writing.
- Prefer updating an existing file over creating a near-duplicate; delete wrong memories.
- Write directly to the memory dir — it already exists; do not `mkdir` or guard for its existence.

## Assets

- `assets/memory-template.md` — the memory-file skeleton (frontmatter + body shape) and the `MEMORY.md` index-line format. Read and fill it in Steps 3 and 4.
