# Session Closer — Gotchas

Load this when a step fails unexpectedly: a script 404s, the transcript cutoff looks stale, `project-state.md` won't `Read` in one call, or `uptime` rejects its flags.

- **`secret-scan` isn't available in every project's skill list** (observed in a
  non-NixOS-repo project with no `secret-scan` skill present) — it's generated
  per-project by `/create-secret-scan`, not a global skill. Don't silently substitute a
  manual grep and move on: ask the user (AskUserQuestion, see STEP 5B) whether to generate
  one now or skip with a manual pass just for this close-out, and record which path was
  taken in the session summary either way.
- **Script and asset paths** (`rotate-session-summary.sh`, `rotate-project-state.sh`, the `assets/`
  templates): use the absolute path from this skill's Base directory line, never a bare
  `scripts/...` / `assets/...` or a project-root-relative `.claude/skills/session-closer/...`
  path (exit 127 / 404; recurred across many sessions) — see `~/.claude/skills/lib/script-paths.md`.
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
- **The transcript cutoff detector used to miss slash-command invocations — fixed 2026-08-10
  (`910c986`).** `find-last-skill-invocation.sh` once only matched assistant `Skill` tool_use
  entries, so a user-typed `/session-closer` never registered; on 2026-08-02 that made STEP 2
  report a stale 2026-07-16 cutoff and pull in 13 transcripts instead of 7. It now also matches
  `<command-name>/<skill-name></command-name>` turns. Keep one sanity check: if the reported
  cutoff predates the latest `chore(session):` commit (`git log --oneline | grep
  'chore(session):' | head -1`, the same baseline STEP 1 computes), only mine transcripts back to
  that commit's date. Don't tail-skim a multi-transcript dump either — transcripts concatenate
  newest-first, so a `tail` surfaces the *oldest* included transcript's content, not a summary
  of the newest.
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
- **STEP 6 commit and push forms.** `git commit -m` drops the `Co-Authored-By:` body: a single
  `-m` has no body, and `-m` plus a heredoc silently loses the heredoc. Use `git commit -F -`.
  Push with the git-push skill's `push.sh execute` (it pushes the current branch, like
  `git push origin HEAD`), not `origin main`: from any other branch, `origin main` pushes
  the stale local `main`, reports success, and leaves the close commit unpushed. On a protected
  default branch, `push.sh` falls back to a `pr/*` branch plus PR (merge via `land-prs`).
- **`secret-scan/SKILL.md` exists on disk but the Skill tool says `Unknown skill: secret-scan`**
  (observed 2026-10-10, Sidekick): the session was launched from the project's old path
  (`~/projects/ADHD-Assistant`) and the directory was renamed mid-session, so the session's
  project-skill list was loaded from a path that no longer exists. That is not the
  "absent" branch of STEP 5B. Don't offer `/create-secret-scan`; `Read`
  `<repo-root>/.claude/skills/secret-scan/SKILL.md` directly and follow its steps by hand.
- **STEP 1 baseline is branch-local** (observed 2026-10-22, NixOS): `scan-session.sh git-changes`
  finds the last `chore(session):` commit in the *current branch's* history. A close that
  merged to `main` as a PR is missing from a feature branch cut before it, so the baseline is
  a stale earlier close and the commit range overstates the session. `git fetch` and compare
  with `git log origin/main --grep='chore(session)'` first; if newer, write the docs in a
  `git worktree add --no-track -b <branch> <dir> origin/main` (leaves the user's checked-out
  feature branch alone, and avoids conflicting with its PR on `project-state.md`).
- **STEP 3's rotation covers three sections, not the whole file** (2026-10-26, NixOS):
  `rotate-project-state.sh` rotates Current Project State, Recent Decisions and Next Steps,
  each into its own archive. Current Goals and Known Issues / Tech Debt are never rotated
  (~34KB and ~41KB on 2026-10-25), so prune them by hand when they bloat. A kept Next Steps
  block that says "Everything from session N below still stands" points into the archive once
  block N rotates out; restate the carried-over items in the new block instead. The script
  aborts with `INTERNAL ERROR ... Nothing was changed` if its split pieces don't add up to
  the original bytes; that is a bug in the script, never a reason to edit the file by hand.
