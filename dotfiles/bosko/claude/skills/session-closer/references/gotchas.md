# Session Closer — Gotchas

Load this when a step fails unexpectedly: a script 404s, the transcript cutoff looks stale, `project-state.md` won't `Read` in one call, or `uptime` rejects its flags.

- **`secret-scan` isn't available in every project's skill list** (observed in a
  non-NixOS-repo project with no `secret-scan` skill present) — it's generated
  per-project by `/create-secret-scan`, not a global skill. Don't silently substitute a
  manual grep and move on: ask the user (AskUserQuestion, see STEP 5B) whether to generate
  one now or skip with a manual pass just for this close-out, and record which path was
  taken in the session summary either way.
- **`scripts/rotate-session-summary.sh` is relative to the *skill's* directory, not the
  project cwd** — running it as `.claude/skills/session-closer/scripts/rotate-session-summary.sh
  <repo-root>` (or the same path prefixed with the project root) fails with exit 127,
  because this repo's session-closer isn't project-local — it's symlinked into
  `~/.claude/skills/session-closer/`. This has recurred across multiple sessions, each time
  wasting a failed attempt before self-correcting. Always invoke it with the absolute path
  from the "Base directory for this skill" line shown when the skill launches (e.g.
  `~/.claude/skills/session-closer/scripts/rotate-session-summary.sh <repo-root>`), never a
  bare `scripts/...` or project-root-relative path. The same applies to
  `scripts/rotate-project-state.sh` (STEP 3's rotation).
- **`project-state.md` has grown too large for a single `Read`** (check live via `wc -l
  /home/bosko/NixOS/project-state.md` — it only grew until STEP 3's
  `scripts/rotate-project-state.sh` rotation existed, and was already past 650 lines /
  270KB as of 2026-07-30; until that rotation has actually been run against a project's
  file, assume it is still oversized). Across several sessions, Step 3 first
  tried a bare `Read project-state.md` (fails), then guessed a large offset/limit window
  (e.g. 236 or 267 lines) that *still* overflowed, before finally landing on a narrower
  range — wasting 2+ failed reads each time. Instead, `grep -n '^## '
  /home/bosko/NixOS/project-state.md` first to find section boundaries, then `Read` only the
  section(s) being updated (~100-150 lines per call) rather than guessing a wide window.
  **The "~100-150 lines" estimate is still too optimistic and has caused repeat overflows**
  (session 2026-07-17: `offset=318 limit=210` → 28,287 tokens; an earlier session:
  `limit=170` → 25,363 tokens — both over the 25k cap). This file's bullets run dense,
  averaging ~130-150 tokens/line, not the ~70/line a "150 lines fits" guess assumes. Use
  `limit=100` or less as the real safe default, and prefer reading exactly up to the next
  `## ` boundary from the `grep` output over guessing any fixed line count at all.
- **The transcript cutoff detector misses slash-command invocations** (`find-last-skill-invocation.sh` only greps for assistant-initiated `Skill` tool_use entries) — when session-closer is run the normal way, via a user-typed `/session-closer`, Claude Code injects its instructions as user-turn content instead of an assistant `Skill` tool_use, so the detector never records it. On 2026-08-02 this made the cutoff report 2026-07-16 as the "last run" even though 2026-07-23 and 2026-07-26 both closed successfully (confirmed via `chore(session)` commits `e122a01`/`f7f0549`), pulling in 13 stale transcripts instead of the 7 actually in scope and nearly causing an old close to be re-narrated as current. **Always treat `git log --oneline | grep 'chore(session):' | head -1` — the same baseline STEP 1's git-changes script already computes — as the authoritative last-close marker for STEP 2's transcript scan too.** If the transcript tool's own reported cutoff predates that commit's date, only mine transcripts back to the commit's date, not the tool's cutoff. Don't tail-skim a multi-transcript dump either — transcripts concatenate newest-first, so a `tail` surfaces the *oldest* included transcript's content, not a summary of the newest.
- **`uptime -p` and `uptime -s` both fail** when confirming a real reboot vs. just a switch
  (observed 2026-08-03: `uptime: invalid option -- 'p'`, same for `-s`) — this system's
  `uptime` is the coreutils build, not procps-ng, so neither flag exists. Use `who -b`
  instead to get the boot timestamp.
- **STEP 5's `README.md` edit failed twice in a row (2026-09-07, session 104)** by
  constructing `old_string` from a remembered/assumed section structure (guessed a
  `## Recent Changes` section with specific prior-entry text) instead of the file's actual
  current content — both attempts got `String to replace not found in file`, and the real
  anchor turned out to belong to a different section (`## Features`) with different
  surrounding text entirely. `Read` the current `README.md` immediately before building the
  Edit's `old_string`; never reconstruct it from memory of what a prior session's entry
  probably looked like.
- **The `scripts/...`-must-be-absolute rule (above) also applies to `assets/` reads, not
  just scripts.** Hit for real: `Read`ing
  `.claude/skills/session-closer/assets/session-summary-template.md` (project-root-relative)
  404'd before self-correcting to the absolute `~/.claude/skills/session-closer/assets/...`
  path from the "Base directory for this skill" line. Same root cause, same fix — use the
  absolute base-dir path for every `assets/` file too, not only `scripts/`.
