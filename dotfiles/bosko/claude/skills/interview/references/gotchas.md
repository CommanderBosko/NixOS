# Interview — Gotchas

Background for the rules in SKILL.md's Gotchas section. Load this only when you need the case behind a rule; the rules themselves stay inline in SKILL.md.

## AskUserQuestion timeout (observed 2026-07-02, and in one earlier session)

- **What went wrong:** AskUserQuestion times out after 60s if the user is away.
- **Rule it produced (inline in SKILL.md):** a timeout is NOT an answer. Restate the same wave as plain numbered text with a recommended default per question, and mark the interview as paused, not advanced.

## Well-scoped-fix exception (observed 2026-07-07)

- **What happened:** the skill was invoked for a Qt platform-plugin bug fix where the root cause was already found via git history. Running Steps 3–8 in full would have meant writing a Project Brief and spawning a second-AI review subagent for what was really a 30-minute fix.
- **Rule it produced (inline in SKILL.md, and in Rules):** a single concrete fix with a clear, already-implied success criterion qualifies for the 1–3 blocking-questions shortcut; the full ceremony is for genuinely fuzzy, multi-part, or open-ended-scope requests.
