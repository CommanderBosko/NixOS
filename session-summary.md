# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-06-23 (session 18) — Claude skill-library audit + overhaul

**Focus**: Audit every skill against a quality rubric, fix what's broken, and capture the workflow as a reusable skill.

### What changed (and why)
- **New skills + `new-skill` gates** (`0a7bd2d`, `dc3e1a4`): added the 4-bucket single-responsibility gate to `new-skill`; created `bump-input` and `save-memory`; split `team-member-ingest` → + `team-member-synthesize`; hardened `new-skill` to auto-wire repo-managed global skills into `bosko-claude.nix`.
- **Drift bug fixes** (`0853706`): `/vpn-status` was broken (`ubuntu@` denied → `bosko@`, verified live); wrong commit trailer (Sonnet 4.6 → Opus 4.8); phantom `server` host; `new-host`'s DE list named 5 nonexistent modules; stale `pin-input` roster — DE list + roster now enumerate live.
- **`.claude/hosts.json` single source of truth** (`f179f8b`): host SSH targets/IPs/WG-peer map centralized; rewired 8 skills + 2 scripts to read it; dropped the phantom `nixos-server`; `remote-rebuild` rewritten vpn-server-only with `boot`+reboot.
- **scripts/ + assets/ + UX** (`a25c339`, `f2e2ec6`): `new-host` 493→180 lines (templates→`assets/`); scripts for diff-generations (fixed a gen-1 baseline bug), fmt, add-secret, audit-config, rollback + shared `.claude/lib/flake-lock-diff.sh`; AskUserQuestion + `## Arguments` across ~11 skills.
- **`/skill-audit` meta-skill** (`f56b9b1`): reproduces the whole audit — disjoint sub-agent partitions, 6-point rubric, report-not-apply.

### Decisions
- **One shared `hosts.json`** killed the `bosko`/`ubuntu` drift class; verify constants against the live system before trusting an inline copy (the docs can be the stale side).
- **Dropped the phantom `nixos-server`, kept `pi-hole`** as a non-flake reference (user choice).
- **Skipped** global-skill `assets/` extraction (per-file symlink overhead) and the `arguments:` YAML frontmatter field (unconfirmed support — used `## Arguments` prose).

### Issues / surprises
- Parallelized both the audit *and* the fix pass across disjoint sub-agent partitions (no file overlap) — disjoint ownership is what made a parallel *edit* pass safe.
- Pure skills-infra session; no NixOS system config touched.

### Next session
- `nh os boot /home/bosko/NixOS` + reboot to surface the `dotfiles/` skill changes (`new-skill`, `git-commit`, `team-member-*`, new `/skill-audit`) in `~/.claude`. Standing backlog unchanged (VPN MTU rebuilds, Avahi firewall).

**Commits**: `0a7bd2d..dc3e1a4` (7 commits)

---

## Session: 2026-06-22 (session 17) — gitignore loop run-logs; FinanceGuru bump

**Focus**: Commit a user-made FinanceGuru flake update, then stop loop run-logs from cluttering `git status`.

### What changed (and why)
- **FinanceGuru input bumped `9cb935a` → `6b506fe`** (`889d6bc`) for an upstream FinanceGuru update — lock-only, nothing else moved. Applies on next `/fleet-rollout`.
- **`.gitignore` rule for loop run-logs** (`90279df`): `.claude/loops/**/output-*.md` and `memory-*.md` are now ignored. Each loop run writes a dated dual-file log there; those are local artifacts, not skills.

### Decisions
- **Ignore loop run-logs, keep loop config tracked** — the loop *skills* live in `.claude/skills/` and are already tracked (so they're portable to any clone); the ignored files are only the per-run dated logs. Chose a narrow `output-*`/`memory-*` glob over ignoring all of `.claude/loops/` so genuine config like `public-repo-guard/baseline-allowlist.md` stays tracked. Verified with `git check-ignore`.

### Issues / surprises
- None. The user's question "I like my skills accessible anywhere" was a misread of what the untracked files were — clarified that the skills were already committed; only run-logs needed handling.

### Next session
- Standing backlog unchanged: laptop + natalie-laptop pending rebuild activations (run via `/fleet-rollout`), `wg0 mtu = 1380` on desktop clients, interface-scope the Avahi mDNS firewall.

**Commits**: `889d6bc`, `90279df` (2 commits). (Pre-session, also pushed: `b541303` flake bump via `/flake-update-verify`, `b9e85c2` push-step added to that loop.)

---

## Session: 2026-06-21 (session 16) — first three loops via `/create-loop`

**Focus**: Put the session-15 `/create-loop` meta-skill to work — generate the first real loops for the fleet.

### What changed (and why)
- Generated three project-local self-orchestrating loops (`bdc9434`): **`/fleet-rollout`** (staged per-host deploy: dry-run gate → switch → full health sweep, gaming→laptop→natalie-laptop→vpn-server), **`/flake-update-verify`** (update inputs → flake-check → commit the lock without applying; restore the previous lock if eval breaks), and **`/public-repo-guard`** (secret-scan + audit-config triaged against a seeded baseline allowlist; passes at zero genuine findings).
- Each verified well-formed before commit: name matches dir, all done-rules machine-checkable, referenced skills resolve, baseline file seeded with this repo's known-intentional exceptions.

### Decisions
- **Rollout uses dry-run-gate-then-`switch` with a live health sweep**, departing from the repo's `boot`-only convention — health checks are meaningless against an inactive config; the dry-run gate still catches eval breaks before any activation.
- **`flake-update-verify` commits the lock but never applies; restores the previous lock on failure** via plain `git checkout -- flake.lock` (the loop's clean-tree precondition makes git the reliable revert source). Applying stays a deliberate `/fleet-rollout` step.
- **`public-repo-guard` converges via a committed baseline-allowlist file**, not run-memory — a durable, diffable list of accepted findings beats re-deriving intentional-vs-genuine each run.

### Issues / surprises
- None. Confirms the session-15 PENDING item: `/create-loop` resolves in a fresh session and runs end-to-end. Empty `loops/*/` dirs for two loops are untracked (git skips empty dirs) — they populate on first run.

### Next session
- Standing backlog unchanged: laptop + natalie-laptop pending rebuild activations (now runnable via `/fleet-rollout`), `wg0 mtu = 1380` on desktop clients, interface-scope the Avahi mDNS firewall.

**Commits**: `bdc9434` (1 commit)

---

## Session: 2026-06-20 (session 15) — `/create-loop` meta-skill

**Focus**: Build a global `/create-loop` skill that interviews the user and generates custom, self-orchestrating loop skills.

### What changed (and why)
- Added `dotfiles/bosko/claude/skills/create-loop/SKILL.md` and wired it into `bosko-claude.nix` (`b6e5d9d`). It's a *meta-skill*: it interviews for a loop's goal/steps/done-rule, then writes a project-local standalone loop to `.claude/skills/<loop>/SKILL.md` that runs as one command.
- Every generated loop has Loop Training Mode (top-of-file toggle, ON by default), a retry cap (default 3), dual-file per-run output (`output-<date>.md` + `memory-<date>.md` under `.claude/loops/<loop>/`), and a built-in verification plan.

### Decisions
- **Generated loops are project-local, not repo-global** — repo-global needs a rebuild per loop (read-only `/nix/store` symlinks); project-local is writable and instant. `/create-loop` itself stays global.
- **Loops are standalone/self-orchestrating**, not thin `/loop` wrappers — a loop is a complete, inspectable artifact; `/loop` can still wrap it for intervals.
- **Per-loop log dir** for the two output files, kept separate from the curated `~/.claude/.../memory/` system.

### Issues / surprises
- `nh os boot` can't run from the agent (no TTY for sudo) — the user activates. For an HM symlink-only change like this, `nh os switch` works with no reboot; a fresh session is needed before `/create-loop` resolves as a command.

### Next session
- Verify `/create-loop` resolves after `switch` + new session; run it once to generate a real loop and confirm the dual-file output + Training Mode behave as documented.

**Commits**: `b6e5d9d` (1 commit)

---

## Session: 2026-06-18 (session 14) — make the Parallelize rule actually trigger

**Focus**: Fix the `Parallelize with Sub-Agents` standing rule so it fires reliably instead of being silently ignored.

### What changed (and why)
- Rewrote the rule in both the repo `CLAUDE.md` and the global `claude-rules` skill source (`ea77515`). The old wording was an aspirational value with no trigger; the new version is a mandatory pre-task gate with concrete, observable trigger conditions.

### Decisions
- **Grant explicit standing authorization to spawn agents** ("you do not need to ask first") — the harness's built-in default is "don't spawn unless asked," which was silently suppressing the rule. The standing rule *is* the persistent ask, so make that explicit.
- **Trigger on independence, not file count** — multi-file edits here are usually coupled (module + its `flake.nix` import + `environment.nix`), which is correctly serial. Named that exception in the rule so it doesn't read as self-contradictory and get ignored wholesale.
- **Apply to both files** — `CLAUDE.md` for immediate effect in this repo; the skill canonical text so future projects inherit it (after a rebuild reaches `~/.claude`).

### Issues / surprises
- None. Docs-only change; no rebuild needed for the Markdown itself.

### Next session
- After the next `rebuild`, the strengthened `claude-rules` skill text reaches `~/.claude` — new projects then inherit the stronger wording.
- Observe whether parallelization actually fires more often in practice; tune the trigger wording if it over- or under-fires.

**Commits**: `ea77515` (1 commit)

---
