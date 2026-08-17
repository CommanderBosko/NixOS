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

Search the project root and one level down for common status-doc filenames. The lookup itself is mechanical (one `-iname` pattern per `find` call — never combine patterns with `-o`, and never use `-not`/`-exec`, since some environments' `find` reject compound predicates outright and fail the whole lookup rather than just matching less), so it's handled by a script:

```bash
bash <skill-base-dir>/scripts/find-status-docs.sh . project-state.md session-summary.md STATUS.md PROGRESS.md NOTES.md CHANGELOG.md
```

Adapt the pattern list to what step 1 turned up, or to filenames the user names directly — pass only the patterns worth trying instead of firing the full default list blindly every time. The judgment is in choosing patterns; the lookup itself is not.

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

- Don't combine multiple filename patterns into one `find -o` command, and don't use `-not`/`-exec` — some `find` shims reject compound predicates outright and fail the whole lookup instead of just matching less. `scripts/find-status-docs.sh` already issues one `-iname`/`-name` pattern per `find` call for this reason — don't reintroduce a compound call by hand.
