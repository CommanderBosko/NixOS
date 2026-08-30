# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-08-30 (session 96) — global `manager` agent built, calibration-tested, merged as PR #15

**Focus**: Build a global "manager" delegate agent that decides tasks the way the user would, backed by a profile mined from their own Claude Code history.

### What changed (and why)
- Built `manager`, a global agent that decides delegated tasks the way this user would ("the smartest call, not necessarily the easiest") instead of interviewing at each step, plus `manager-profile.md` — mined via 12 parallel `transcript-scanner` agents across every project with Claude Code history, not just this one.
- Ships in supervised training mode by default, six hard limits that always require confirmation (no data destruction/force-push, no touching secrets, no spending money, no direct privileged/live-system execution, no pushing straight to `main`, no mutating MCP calls), lands only via branch+PR.
- New skill `refresh-manager-profile` re-mines transcripts incrementally on demand.

### Decisions
- The mined profile needed the user's own explicit sign-off before its first push — a standing rule baked into the profile itself, since it steers future unsupervised decisions.
- `manager`'s `AskUserQuestion` fallback codified as "stop completely, never trust relayed consent" rather than assuming the tool is always reachable — see Issues below.

### Issues / surprises
- Live calibration test (synthetic sandbox repo, deleted after) found `AskUserQuestion` isn't available to `manager` when spawned as a background subagent — only an interactive main-session turn has it. The sandbox also had no `main` ref, so the "never push directly to a default branch" hard limit was live from the start; `manager` refused three escalating relay-consent attempts and only proceeded once the repo state became independently checkable. User graded this "exactly right, keep it this strict." Codified same-session (commit `c863102`).

### Next session
- None — fully live, `nh os switch` already applied, PR #15 squash-merged, CI green.

**Commits**: `b56533e` (1 commit, 2 sub-commits squashed)

---

## Session: 2026-08-30 (session 95) — save-memory promoted to a global skill, "phantom skill" mystery closed

**Focus**: Answer whether `save-memory` was local or global, and promote it to global as requested.

### What changed (and why)
- Found `save-memory`'s `SKILL.md` + `assets/memory-template.md` sitting at `.claude/skills/save-memory/` (project-local) — not missing, just never checked there. Session 92 had flagged it a "phantom skill" after checking only the two global paths (`~/.claude/skills/`, `dotfiles/bosko/claude/skills/`).
- Moved it to `dotfiles/bosko/claude/skills/save-memory/` and added a recursive-dir `home.file` entry in `bosko-claude.nix` (matching `interview`/`new-skill`'s pattern), so it now symlinks into `~/.claude/skills/` on every host.
- Fixed the SKILL.md's own Gotchas section, which claimed "project-local-only, no global copy exists" — now points at the real global path.

### Decisions
- Read "if it's local, make it global" as a request to actually promote it, not just report the finding.

### Issues / surprises
- Session 92's "phantom skill" report was itself the bug — a simple missed-directory check, not a real registration mystery. Corrected in memory `project_skill_roster_state` and `project-state.md`.

### Next session
- All 3 desktop hosts still need a rebuild to pick this up in `~/.claude/skills/` (rides along with the existing pending-switch pile — no reboot needed, pure symlink change).

**Commits**: `7b8c3e3` (1 commit)

---

## Session: 2026-08-27 (session 94) — Godot 4 dev environment for Legions, promoted to a shared desktopModules module

**Focus**: Add a durable godot-mono/dotnet-sdk dev environment for the Legions game project, then right-size its scope as requirements clarified.

### What changed (and why)
- Added `godot-mono` (4.7.2-stable, C#-enabled build) and `dotnet-sdk` (8.0.424) for game dev — first to gaming+laptop's `environment.nix` directly, then extracted into `modules/development.nix` (imported per-host, like `nvidia.nix`) once the user asked whether the resulting duplication was worth fixing.
- User then said natty might develop too and asked to centralize dev tooling for all desktop users — promoted `development.nix` into `desktopModules` so it reaches gaming/laptop/natalie-laptop for both users, removing the two now-redundant per-host imports. Updated `CLAUDE.md`'s `desktopModules` bullet to match.
- Separately, `repo-creator` (commit `9380a65`, the evening before) gained a required visibility argument — asks via `AskUserQuestion` with no default instead of silently defaulting to `--public`.

### Decisions
- See project-state.md Recent Decisions for the full writeup — the key one: scoped `development.nix` by *who needs it*, not by "is this a dev tool," and explicitly declined sweeping bosko-personal (`claude-code`/`mcp-nixos`/etc.) or already-universal (`kate`/`kitty`/etc.) packages into it even when asked to reconsider.

### Issues / surprises
- None — both refactors verified byte-identical package diffs before/after via dry-run + `shared-module-check`'s 4-host deep-eval.

### Next session
- gaming/laptop/natalie-laptop still need a rebuild to actually get `godot4`/`dotnet` on PATH — stacks with the existing pending-switch pile (2026-08-25 flake bump, Tailscale MCP connector, and everything older).

**Commits**: `9380a65..512561e` (3 commits)

---

## Session: 2026-08-25 (session 93) — Fixed a real git-permission injection bug flagged by Claude Code's own startup warning

**Focus**: Fix the wildcard-before-subcommand permission rules Claude Code's startup popup flagged, then audit the rest for the same shape.

### What changed (and why)
- Claude Code's own startup warning flagged `Bash(git -C * status)`/`Bash(git -C * log *)` in `.claude/settings.json` — the wildcard sat before the git subcommand, so an injected `-c`/`--exec-path` option could hide there and get auto-approved without a prompt. Found and fixed the same-shaped `Bash(git -C * diff*)` too, even though it wasn't in the popup.
- Fix: hardcoded `/home/bosko/NixOS` (the only path these rules are ever actually used with, across every skill that calls `git -C`) instead of narrowing the wildcard — no injectable gap left before the subcommand.
- Audited all three permission files (project `settings.json`/`settings.local.json`, global `~/.claude/settings.json`) for the same pattern — none found; every remaining wildcard is a safe trailing suffix.

### Decisions
- See project-state.md Recent Decisions for the full writeup.

### Issues / surprises
- None — clean fix, clean audit.

### Next session
- Nothing pending from this session.

**Commits**: `599276f` (1 commit)

---

## Session: 2026-08-25 (session 92) — Flake bump, 3 new skills, PR #12 merged, Tailscale MCP connector committed

**Focus**: Close out a busy day spanning 6 sessions — flake maintenance, skill-suggestion sweep, weekly PR review, and Tailscale/pi-hole follow-up work.

### What changed (and why)
- `/flake-update-verify` bumped nixpkgs/home-manager/dms and pushed the lock-only commit (`c84892f`) after the mandatory eval-verified commit gate.
- A `skill-suggestion`/`agent-suggestion` sweep shipped 3 new project-local skills via `ship-skill` — `pihole-api` (session-auth wrapper, retyped 6x by hand before this), `package-nix-tool` (external-tool packaging workflow, done twice before), `diagnose-hung-game` (Steam/Proton freeze runbook) — plus a real nullglob fix to `verify-service.sh`. Each smoke test caught and fixed a real live bug (see project-state.md for specifics).
- `review-improve-system-pr`'s first real run against a live weekly PR: reviewed and merged PR #12 (5 self-verifiable skill fixes from the `improve-system` cloud routine).
- Committed the already-built Tailscale MCP connector (`e8c183a`) — the connector itself was designed/packaged in an earlier session that day; this just shipped it.
- Verified Tailscale/pi-hole health (all clean) and re-confirmed two already-tracked issues (natalie-laptop CIFS stall, pi-hole blocklist research) needed no new work.

### Decisions
- User declined bumping the 3 NixOS hosts' outdated Tailscale client for now ("skip for now") — not an oversight, a deliberate pass.
- `package-nix-tool`'s smoke test deliberately only exercised the deterministic hash-resolution script, not a full end-to-end package build — judged too consequential for a smoke test.

### Issues / surprises
- Found a genuinely phantom skill: `save-memory` is listed as invocable in the roster but has no backing file anywhere (repo or `~/.claude`) — flagged for next session, not chased further.
- Two stale memory notes corrected: `review-improve-system-pr` had "not yet run against a live PR" (now has, cleanly); `improve-system`'s "3rd run outcome UNCONFIRMED" was actually wrong — two real self-verifiable PRs (`443fb9a`, PR #12) have landed since the 2026-07-27 hardening.

### Next session
- gaming/laptop/natalie-laptop all need a rebuild to pick up the flake bump, the Tailscale MCP connector, `gemini-cli`'s removal, and PR #12's global-skill fixes — one reboot covers all of it.
- Post-rebuild: live-verify the Tailscale MCP connector actually works from a real Claude Code session.
- Investigate the phantom `save-memory` skill.

**Commits**: `d3ea435..c84892f` (7 commits)

---

