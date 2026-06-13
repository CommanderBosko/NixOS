---
name: session-closer
description: Close out a work session — summarize everything done, update project docs, and push to GitHub. Use when the user says "close the session", "close out the session", "end of day", "I'm done for the day", "wrap up the session", or "end the session".
---

# Session Closer

Execute a thorough, structured end-of-day session-closing workflow for the current
project. The goal: no work is lost or undocumented, every state file reflects reality,
and the day's work is committed and pushed.

Work in the current project's repository. Run all git commands against that repo.

---

## STEP 1 — Scan for changes

- Find the last session-close commit:
  `git log --oneline --all | grep "chore(session):" | head -1`
- Use it as the baseline: `git log --oneline <last-session-commit>..HEAD --all` for every
  commit since the last close. If no session-close commit exists, fall back to
  `git log --oneline --since='midnight' --all`.
- `git diff origin/main...HEAD` — changes not yet pushed.
- `git status` — uncommitted changes.
- `git log --stat <last-session-commit>..HEAD` — which files changed and how much.
- Collect branch names, commit messages, and changed files.
- If there are uncommitted changes, stage with `git add -A` and create a meaningful
  commit summarizing the session before proceeding.

---

## STEP 2 — Summarize the work

Build a complete picture of the session:
- Every file changed, added, or deleted.
- What each major change accomplishes functionally.
- Themes (bug fixes, features, refactors, docs, config).
- Breaking changes, new dependencies, architectural decisions.
- Blockers, open issues, or unfinished work for next time.

Be specific — never "made improvements." Instead: "Refactored the auth middleware to
support JWT refresh tokens."

---

## STEP 3 — Update `project-state.md`

Locate or create `project-state.md` (or the project's equivalent state file) at the repo
root and update:
- **Current Project State** — what works, what's in progress, what's broken.
- **Current Goals** — short-term (next 1-3 sessions) and long-term.
- **Recent Decisions** — architectural/technical/product decisions made this session.
- **Known Issues / Tech Debt** — problems found but not yet resolved.
- **Next Steps** — clear, actionable items for next session.

---

## STEP 4 — Update `session-summary.md`

A running log at the repo root. **Prepend** the new entry — most recent first, never
overwrite history.

```markdown
## Session: [DATE] — [Brief Session Title]

**Duration Estimate**: [if inferrable from commit timestamps]
**Session Focus**: [one-sentence primary goal]

### What Was Accomplished
- [completed work items]

### Files Changed
- `[filename]` — [what changed and why]

### Commits This Session
- `[commit hash]` — [commit message]

### Decisions Made
- [important decisions, with rationale]

### Issues Encountered
- [bugs, blockers, surprises]

### Remaining / Next Session
- [what needs to happen next]

---
```

---

## STEP 5 — Update `README.md`

Refresh (or create) the project `README.md` so it matches the current codebase —
professional, accurate (no aspirational features), well-structured:

```markdown
# [Project Name]

[One-paragraph description]

## Current Status
[e.g. "Active development, v0.3 alpha"]

## Features
[implemented features]

## Getting Started
### Prerequisites
### Installation
### Configuration
### Running

## Project Structure
[key directories and purposes]

## Recent Changes
[last 1-3 sessions' major changes]

## Roadmap
[near-term planned work]

## Contributing
## License
```

Preserve existing sections that are still accurate — only update what changed.

---

## STEP 6 — Commit and push

No confirmation needed — draft and execute directly.

1. Stage the docs: `git add session-summary.md README.md project-state.md`
   (plus any other files touched in Step 1).
2. Commit: `git commit -m "chore(session): end-of-day close [DATE] — [brief summary]"`
   End the commit message body with:
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
3. Push: `git push origin main` (never `--force`, never `--no-verify`).
4. Confirm the push succeeded and report the final commit hash.

---

## Output to the user

```
✅ SESSION CLOSED — [DATE]

📋 Summary: [2-3 sentence overview]
📁 Files Changed: [count]
💾 Commits Pushed: [count]
📝 Docs Updated: session-summary.md, README.md, project-state.md
🚀 Pushed to: origin/main ([commit hash])

🎯 Next Session Focus:
  - [top 2-3 next steps]
```

---

## Edge cases

- **No changes today** — document it as a planning/review session; still add a
  "no code changes" entry to session-summary.md.
- **Merge conflicts** — flag clearly, do NOT force-push; tell the user to resolve first.
- **Missing git remote** — warn, complete all local file updates, skip the push.
- **Large diffs** — summarize by file group / feature area, not line by line.
- **First-time run** — create session-summary.md / project-state.md / README.md from
  scratch with sensible initial content.

---

## Memory

This skill runs in the main conversation, which already has the project memory system.
If you discover something durable while closing out — a recurring work pattern, an
architectural decision and its rationale, the project's evolving goals — save it through
the normal memory workflow. Don't save ephemeral session details or anything `git log`
already records. Cross-check existing memory before writing next-session reminders so you
never re-list completed work as pending.
