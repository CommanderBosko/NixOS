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
- This gives you the *what*; STEP 2 reads the session transcript for the *why*.
- If the range spans more than the current conversation's work (e.g. several prior
  sessions were never closed), say so plainly and **only narrate what you actually did
  this session** — don't invent rationale for commits you weren't part of. Refresh the
  state files to current reality regardless.
- If there are uncommitted changes, stage with `git add -A` and create a meaningful
  commit summarizing the session before proceeding.

---

## STEP 2 — Identify what git won't tell you

### Read the session transcript first (ground truth)

Don't reconstruct the session from your live context window — it gets summarized and
truncated as a conversation grows, so decisions, rationale, and surprises from early in
the session may have scrolled out. The **JSONL transcript on disk is the complete,
unsummarized record** of this session, so read it for the most accurate close.

Locate the current project's transcript dir and grab the most-recently-modified file (the
live session is the one still being written):

```bash
DIR="$HOME/.claude/projects/$(pwd | sed 's#/#-#g')"
LATEST=$(ls -t "$DIR"/*.jsonl 2>/dev/null | head -1)
```

Read it **judiciously** — these files run to several MB, so don't dump raw JSONL into
context. Extract the turns that matter with `jq`:

```bash
# Every user request this session (what was actually asked, in order)
jq -r 'select(.type=="user") | .message.content
       | if type=="string" then . else (.[]? | select(.type=="text") .text) end' "$LATEST"

# Your own narrative/decisions (assistant text, skipping tool calls)
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") .text' "$LATEST"
```

Mine these for the decisions, dead-ends, and gotchas below — the transcript captures the
*why* behind each commit, which git never records. If the close spans more than one
session (several `.jsonl` files since the last `chore(session):` commit), read each
relevant transcript, but only narrate work you can see was actually done.

### Then capture what vanishes otherwise

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

Read the entry template from `assets/session-summary-template.md` (relative to this
skill's directory) and fill its `[...]` placeholders from this session's actual work, then
prepend the filled result to `session-summary.md`.

**Rotation — keep the active log lean.** After prepending, the active
`session-summary.md` should hold only the **~5 most recent** session entries; older entries
move into `session-summary-archive.md` (same format, most-recent-first). This is
deterministic — splitting on the `## Session:` delimiter, keeping 5, archiving the rest,
and inserting the pointer line — so it's handled by the script:

```bash
scripts/rotate-session-summary.sh <repo-root>
```

Pass the current project's repo root (default `.`); set `KEEP=<n>` to keep a different
count. It's idempotent (a no-op when there are ≤5 entries), creates
`session-summary-archive.md` on first rotation, prepends newly-archived entries ahead of
existing ones, and adds the
`_Older entries are in [session-summary-archive.md](session-summary-archive.md)._` pointer.
Run it **after** prepending the new entry. Stage the archive file in Step 6 if it rotated.

---

## STEP 5 — Update `README.md`

Refresh (or create) the project `README.md` so it matches the current codebase —
professional, accurate (no aspirational features), well-structured. This is a real
deliverable, especially for a public repo. Preserve existing sections that are still
accurate — only update what changed; the **Recent Changes** section should cover the last
1-3 sessions.

**No sensitive or secret information — the README is public.** Don't carry a redaction
rubric here: the repo ships a `secret-scan` skill that owns exactly this. After you finish
writing/editing the README, **invoke `secret-scan`** for the public-safety pass — it covers
key material (WireGuard/SSH/age-sops/TLS, password hashes, tokens, API keys), real network
coordinates (endpoint/internal IPs, VPN subnets, MAC addresses, reachable hostnames), and
personal data, across both the working tree and git history. Redact anything it flags in
the README, prefer describing secrets as sops-managed rather than naming values, and note
any redaction in the session summary.

Read the skeleton from `assets/readme-template.md` (relative to this skill's directory)
and fill it in (or use it as the section skeleton when updating an existing README),
preserving existing accurate sections rather than blanking them.

---

## STEP 6 — Commit and push

No confirmation needed — draft and execute directly.

1. Stage the docs: `git add project-state.md README.md session-summary.md`
   (plus `session-summary-archive.md` if you rotated, plus any files touched in Step 1).
2. Commit: `git commit -m "chore(session): end-of-day close [DATE] — [brief summary]"`
   End the commit message body with a `Co-Authored-By:` trailer using whatever model name the
   harness's own Bash-tool commit-message instructions specify (e.g. "Claude Sonnet 5") — don't
   hardcode a specific model name here, it will drift the next time the underlying model changes.
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

## Gotchas

- **`secret-scan` isn't available in every project's skill list** (observed in a
  non-NixOS-repo project with no `secret-scan` skill present). When it's missing, don't
  skip the public-safety pass — do a manual grep for common secret patterns (private key
  headers, `password`/`token`/`api_key`/`secret` literals) across the changed files before
  publishing README changes, and note in the session summary that `secret-scan` wasn't
  available so a manual check was substituted.
- **`scripts/rotate-session-summary.sh` is relative to the *skill's* directory, not the
  project cwd** — running it as `.claude/skills/session-closer/scripts/rotate-session-summary.sh
  <repo-root>` (or the same path prefixed with the project root) fails with exit 127,
  because this repo's session-closer isn't project-local — it's symlinked into
  `~/.claude/skills/session-closer/`. This has recurred across multiple sessions, each time
  wasting a failed attempt before self-correcting. Always invoke it with the absolute path
  from the "Base directory for this skill" line shown when the skill launched (e.g.
  `~/.claude/skills/session-closer/scripts/rotate-session-summary.sh <repo-root>`), never a
  bare `scripts/...` or project-root-relative path.
- **`project-state.md` has grown too large for a single `Read`** (currently 381 lines /
  ~137KB, ~35k tokens against a 25k-token Read limit). Across several sessions, Step 3 first
  tried a bare `Read project-state.md` (fails), then guessed a large offset/limit window
  (e.g. 236 or 267 lines) that *still* overflowed, before finally landing on a narrower
  range — wasting 2+ failed reads each time. Instead, `grep -n '^## '
  /home/bosko/NixOS/project-state.md` first to find section boundaries, then `Read` only the
  section(s) being updated (~100-150 lines per call) rather than guessing a wide window.

## Assets

- `assets/session-summary-template.md` — the `## Session: [DATE] — [Brief Session Title]` entry template used in STEP 4. Read it, fill its `[...]` placeholders from this session's actual work, and prepend the result to `session-summary.md`.
- `assets/readme-template.md` — the `README.md` section skeleton used in STEP 5. Read it and use it to fill/refresh the project's `README.md`, preserving existing accurate sections.
