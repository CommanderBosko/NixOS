---
name: resume-session
description: Locate and summarize whatever status/progress docs a project keeps (e.g. project-state.md, session-summary.md, STATUS.md) to catch up on where things left off. Use when the user says "resume session", "catch me up", "where did we leave off", "/resume-session", or "what's the project status".
---

# Resume Session

Find whatever status/progress docs this project keeps — the filenames vary per project — and read them back to the user as a concise catch-up: current state, what's in flight, what's next. This is a read-only recon skill; it doesn't edit anything.

## Steps

### 1. Check for a documented convention first

Before guessing filenames, check whether the project already names its own convention — grep `CLAUDE.md` and `README.md` (if present) for words like "project-state", "session-summary", "status", "progress", or "changelog". If one is named explicitly, search for that file specifically instead of the generic list in step 2.

### 2. Locate the docs

Search the project root and one level down for common status-doc filenames. **Issue one `-iname` pattern per `find` call — never combine patterns with `-o`, and never use `-not`/`-exec`.** Some environments' `find` (e.g. an `rtk find` shim) reject compound predicates outright and fail the whole lookup rather than just matching less; running separate calls also parallelizes cleanly since they're independent:

```bash
find . -maxdepth 2 -iname "project-state.md"
find . -maxdepth 2 -iname "session-summary.md"
find . -maxdepth 2 -iname "STATUS.md"
find . -maxdepth 2 -iname "PROGRESS.md"
find . -maxdepth 2 -iname "NOTES.md"
find . -maxdepth 2 -iname "CHANGELOG.md"
```

Adapt the pattern list to what step 1 turned up, or to filenames the user names directly. Skip patterns that clearly don't fit the project's conventions rather than firing all of them blindly every time.

### 3. Read what's found

Read each file that matched, most-recently-modified first if there are several. If nothing matched, say so plainly and ask the user where their status docs live — don't guess further or fabricate one.

### 4. Summarize

Report back, concisely, in the project's own terms (not generic filler):
- Current overall state/phase
- What was done most recently
- What's explicitly in-flight or blocked
- What's next

Cite which file(s) each fact came from, so the user can go straight to the source for more detail.

## Gotchas

- Don't combine multiple filename patterns into one `find -o` command, and don't use `-not`/`-exec` — some `find` shims reject compound predicates outright and fail the whole lookup instead of just matching less. Always issue one `-iname`/`-name` pattern per `find` call.
