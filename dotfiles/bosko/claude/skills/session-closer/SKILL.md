---
name: session-closer
description: Close out a work session — summarize everything done, update project docs, and push to GitHub. Use when the user says "close the session", "close out the session", "end of day", "I'm done for the day", "wrap up the session", or "end the session".
---

# Session Closer

Close out a work session so the **next** session — you or the user — starts with accurate
context. The win here is *curation*, not exhaustive logging. Git already records what
changed and when; this skill captures what git can't: **why** a change was made, **what's
live vs. pending vs. broken**, and **what's blocked**. It also keeps the state files
honest so they don't quietly drift out of date.

Bias your effort accordingly: `project-state.md` and `README.md` are the files that
actually get re-read to prime context, so they get the care. `session-summary.md` is a
human-facing narrative log — keep its entries short, and rotate old ones out. For things
*you* (Claude) need to recall next session, prefer the **memory system** over the prose
log (see Memory below).

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
- If the range spans more than the current conversation's work (e.g. several prior
  sessions were never closed), say so plainly and **only narrate what you actually did
  this session** — don't invent rationale for commits you weren't part of. Refresh the
  state files to current reality regardless.
- If there are uncommitted changes, stage with `git add -A` and create a meaningful
  commit summarizing the session before proceeding.

---

## STEP 2 — Identify what git won't tell you

Git already has the file list and commit messages. Spend your attention on the things
that vanish otherwise:
- **Decisions and their rationale** — what you chose and *why*, including roads not taken.
- **State transitions** — what is now live, what is staged but pending a rebuild/reboot,
  what is broken or deferred.
- **Blockers and surprises** — anything that bit you and would bite again.
- **New dependencies / architectural shifts.**

Be specific — never "made improvements." Instead: "Moved WireGuard private keys into
sops-nix so the repo could be public; kept the endpoint IP in-repo since it's not a
secret."

---

## STEP 3 — Update `project-state.md`  (PRIMARY deliverable)

This is the highest-value artifact — it's what primes a cold start. Make it *accurate*
above all; actively fix anything that is now false (stale "pending" items, superseded
decisions, wrong status). Locate or create `project-state.md` at the repo root and update:
- **Current Project State** — what works, what's in progress, what's broken.
- **Current Goals** — short-term (next 1-3 sessions) and long-term.
- **Recent Decisions** — architectural/technical/product decisions made this session.
- **Known Issues / Tech Debt** — problems found but not yet resolved.
- **Next Steps** — clear, actionable items for next session.

---

## STEP 4 — Update `session-summary.md`  (concise log + rotation)

A running, human-facing log at the repo root. **Prepend** the new entry — most recent
first, never overwrite history. Keep it **short**: skip the exhaustive file list (git
`--stat` has it); a one-line commit range is plenty. Focus on narrative and decisions.

```markdown
## Session: [DATE] — [Brief Session Title]

**Focus**: [one sentence — the primary goal]

### What changed (and why)
- [the few things that matter, with rationale — not a file-by-file dump]

### Decisions
- [important decisions + why]

### Issues / surprises
- [anything that bit you]

### Next session
- [actionable next steps]

**Commits**: `[oldest]..[newest]` ([n] commits)

---
```

**Rotation — keep the active log lean.** After prepending, the active
`session-summary.md` should hold only the **~5 most recent** session entries. Move older
entries into `session-summary-archive.md` (same format, most-recent-first), creating it
on first rotation. Keep a one-line pointer near the top of the active file:
`_Older entries are in [session-summary-archive.md](session-summary-archive.md)._`
Splitting on the `## Session:` delimiter with `awk` is the clean way to do this on a large
file. Stage the archive file in Step 6 if you rotated.

---

## STEP 5 — Update `README.md`

Refresh (or create) the project `README.md` so it matches the current codebase —
professional, accurate (no aspirational features), well-structured. This is a real
deliverable, especially for a public repo. Preserve existing sections that are still
accurate — only update what changed; the **Recent Changes** section should cover the last
1-3 sessions.

```markdown
# [Project Name]

[One-paragraph description]

## Current Status
## Features
## Getting Started   (Prerequisites / Installation / Configuration / Running)
## Project Structure
## Recent Changes
## Roadmap
## License
```

---

## STEP 6 — Commit and push

No confirmation needed — draft and execute directly.

1. Stage the docs: `git add project-state.md README.md session-summary.md`
   (plus `session-summary-archive.md` if you rotated, plus any files touched in Step 1).
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
📝 Docs Updated: project-state.md, README.md, session-summary.md
🚀 Pushed to: origin/main ([commit hash])

🎯 Next Session Focus:
  - [top 2-3 next steps]
```

---

## Edge cases

- **No changes today** — document it as a planning/review session; still add a short
  "no code changes" entry to session-summary.md.
- **Merge conflicts** — flag clearly, do NOT force-push; tell the user to resolve first.
- **Missing git remote** — warn, complete all local file updates, skip the push.
- **Large diffs / multi-session range** — summarize by feature area, not line by line, and
  only claim work you actually did.
- **First-time run** — create the state files from scratch with sensible initial content.

---

## Memory

This skill runs in the main conversation, which has the project memory system. For durable
facts **you** need to recall next session — an architectural decision and its rationale, a
recurring gotcha, the project's evolving goals — write them to **memory**. Memory is
curated and auto-loaded into context at session start, so it serves your recall far better
than a long prose log does.

Keep the channels distinct: `session-summary.md` is the human-facing narrative; memory is
your working recall. Don't duplicate the same content into both, and don't save anything
`git log` already captures. Cross-check existing memory before writing next-session
reminders so you never re-list completed work as pending.
