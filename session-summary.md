# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

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

## Session: 2026-08-24 (session 91) — Removed gemini-cli from all hosts and users

**Focus**: Drop `gemini-cli` entirely — no longer in use.

### What changed (and why)
- Removed `gemini-cli` from `modules/users.nix` for both `bosko` and `natty` — the only 2 references in the whole repo, both in this shared module (`commonModules`, so it covers all 4 hosts). `natty`'s package list is now empty.
- Updated `README.md` (user-packages bullet, Users table, Recent Changes) to match; left historical mentions in `session-summary-archive.md` and `.claude/loops/flake-update-verify/` run logs alone as point-in-time records.

### Decisions
- Retired session 74/78's "leave the removal warning as-is" call along with the package — that nixpkgs `meta.problems.removal` eval warning (Google deprecating Gemini CLI for Antigravity CLI) is now moot.
- Didn't touch `session-summary-archive.md` or old loop output/memory logs — those record what was true at the time, not live config.

### Issues / surprises
- None.

### Next session
- All 4 hosts still need a `switch`/`boot` to actually drop the package from the store (pure package-list change, no reboot required).

**Commits**: `406b373` (1 commit)

---

## Session: 2026-08-24 — Auto Mode setup made declarative across all hosts

**Focus**: Figure out why laptop needed its own manual `/auto-mode-setup` run despite Auto
Mode supposedly being "global," then fix it so no host ever needs the manual pass again.

### What changed (and why)
- Confirmed gaming's `~/.claude/settings.json` already had the full `defaultMode`/`autoMode`
  policy from an earlier setup — nothing to gain from re-running `/auto-mode-setup` there.
- Root-caused the laptop confusion: "global" in the prior session's memory meant global
  *across projects on one machine*, not across hosts — `~/.claude/settings.json` is
  per-machine runtime state, so each host needs its own `/auto-mode-setup` pass.
- User asked to have gaming's setup applied to laptop and natalie-laptop too. Instead of
  another manual pass, added a `home.activation.claudeAutoMode` block to
  `dotfiles/bosko/bosko-claude.nix` that full-reconciles `permissions.defaultMode="auto"`
  plus the entire `autoMode.soft_deny`/`environment` policy into `~/.claude/settings.json`
  on every rebuild — same full-reconcile pattern as the existing `claudeMcpServers` block.

### Decisions
- Full-reconcile (overwrite to canonical), not additive merge — autoMode is repo policy,
  not user-editable state, matching the file's existing `claudeMcpServers` convention over
  its `claudeAllowList` one.
- vpn-server correctly excluded — no home-manager `bosko` user there, confirmed via
  `modules/home-manager.nix`, so this only reaches gaming/laptop/natalie-laptop.

### Issues / surprises
- First implementation attempt shell-interpolated the JSON via a bash single-quoted string;
  broke because several `environment` strings contain apostrophes ("this repo's stated
  normal flow") that prematurely closed the quote — `nh os boot --dry` failed with a bash
  syntax error. Fixed with `pkgs.writeText` + `jq --slurpfile`, which avoids shell quoting
  of the content entirely.

### Next session
- laptop and natalie-laptop: pull + rebuild to pick up `f01382b` (user says they'll handle
  this themselves).

**Commits**: `f01382b` (1 commit)

---

