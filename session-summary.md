# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-09-02 (session 98) — rebuild-boot/rebuild-switch alias split; Meta+G launch-set fix

**Focus**: Two small quality-of-life fixes on the gaming host — a shell alias split, and repairing/trimming the Meta+G app-launch keybind.

### What changed (and why)
- Added a `rebuild-switch` shell alias (`nh os switch`) alongside the existing one, renamed to `rebuild-boot` (was `rebuild`) to avoid confusion between the two apply modes. `modules/shell.nix` + `CLAUDE.md`'s alias list updated to match. Committed `dce0913`.
- Meta+G was reported broken ("no longer opens Deezer"); live-testing showed it was never actually broken — `flatpak run dev.aunetx.deezer` just has a ~10s Electron cold-start and lands on a monitor (dell-3) easy to miss under the old bind's heavier load (kitty + 2× Zen + everything else at once). Fixed by trimming the launch set to what the user actually wanted: Steam, Vesktop, Lutris, Deezer, qBittorrent — dropping kitty and Zen. `dotfiles/common/configs/niri-config.kdl:387`, committed `a5fa6b1`.

### Decisions
- None beyond the fix itself — both were direct, unambiguous requests.

### Issues / surprises
- Meta+G's "broken" report was a false alarm caused by app-launch ordering/cold-start latency, not a real regression — worth remembering next time a multi-app spawn-sh bind gets blamed for one app "not opening."

### Next session
- All 3 niri hosts still need a rebuild/switch to pick up both fixes (no reboot needed for either) — stacks on the existing pending-switch pile (save-memory PR #16, godot dev env, Tailscale MCP connector, etc.).

**Commits**: `dce0913`..`a5fa6b1` (2 commits)

---

## Session: 2026-08-31 (session 97) — save-memory PR #16 merged via `manager`; auto-mode classifier root-caused for FinanceGuru

**Focus**: Fix a cross-repo bug flagged by FinanceGuru (`save-memory` hardcoded NixOS's own memory dir) by delegating to `manager`; separately diagnose why FinanceGuru's session couldn't self-escalate its own permission mode.

### What changed (and why)
- FinanceGuru's session flagged `save-memory` hardcoding `/home/bosko/.claude/projects/-home-bosko-NixOS/memory/` in three spots, correctly out-of-scope there since the skill's source lives here. Delegated the fix to `manager` rather than doing it by hand — first real cross-repo bug report routed to the delegate.
- `manager` rewired all three hardcoded spots to resolve via the shared `find-transcript-dir.sh` lib (same one `research`/`refresh-manager-profile` use), bumped `save-memory` 0.2.0→0.2.1, ran `public-repo-guard` clean, landed via branch+PR (never self-merges). Reviewed and merged (`4475e6d`).

### Decisions
- FinanceGuru's `Blocked by classifier` errors (spawning `manager`, editing `settings.local.json`) traced to a real asymmetry: this repo's `autoMode.environment` profile names it as trusted, FinanceGuru's doesn't, and separately the classifier appears to hard-block a session from escalating its own permission mode when there's no human present to approve (background/agent-view session) — an interactive terminal doing the same toggle isn't gated. Advised the user to flip the mode from an actual interactive FinanceGuru session rather than try to route around the block. No repo change.

### Issues / surprises
- None new — both threads resolved cleanly.

### Next session
- All 3 desktop hosts still need a rebuild to pick up the PR #16 fix (stacks on the existing pending-switch pile — godot dev env, Tailscale MCP connector, 2026-08-25 flake bump, etc.).

**Commits**: `4475e6d` (1 commit)

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

