# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-09-03/04 (session 99) — `/dream` suite built, merged, and run for real; PR #14 merged; flake bumped

**Focus**: Review the weekly `improve-system` PR, build and ship the `/dream` memory-improvement suite (4 new global skills), fix a real bug it hit on first live use, run it for real for the first time, and bump flake inputs again.

### What changed (and why)
- **PR #14** (weekly `improve-system` sweep, 8 doc-only `SKILL.md` fixes) reviewed via the `manager` agent and merged (`75addf7`) after independently re-verifying every fix against live repo state.
- **`/dream` suite** — 4 new global skills (`session-analysis`, `improve-memory`, `send-results`, `dream`) built via `manager`, merged as PR #17 (`256a7cc`). Mines every project's session history for durable memory-worthy facts, reconciles them against real memory + CLAUDE.md, and reports to Discord via a new `discord-webhook-url` sops secret.
- **`send-results` fixed same-day** (`0748119`) — Discord never renders `file://` links as clickable, on any device. Redesigned to publish the reported file as a Claude Artifact and link to the resulting `https://` URL instead. Live-tested end-to-end (real Artifact, real Discord post, confirmed clickable).
- **First-ever full-history `/dream` run** — no repo commit (writes to `~/.claude/dream/` + project memory dirs). Mined all 12 known projects via 21 parallel `transcript-scanner` batches, ~70 candidates, auto-applied 13 wikilink fixes + 8 file updates + 9 new memory files; nothing needed human sign-off.
- **Flake bump** (`2d11999`) — nixpkgs/home-manager/dms/dank-qml-common/financeguru/sops-nix moved; `financeguru` finally unstuck after 5 frozen runs. Verified clean, not yet applied to any host.

### Decisions
- Accepted the trade-off that `send-results`' reported content now leaves the local machine (published as a shareable Artifact) since a local-only link could never actually be clickable in Discord.
- PR #14's merge came back flagged with a "Blocked by classifier" security warning; manually audited the merging subagent's full tool-call trace, found nothing wrong, and reported it to the user as verified-clean-but-flagged rather than either dismissing it or treating the flag as proof of a real problem.

### Issues / surprises
- The first `/dream` build attempt died mid-way from an API rate limit (no `/loop` active to schedule a resume) after most of the work was already staged — a manager subagent that hits a rate limit fails outright rather than pausing, and a failed background task doesn't self-retry. A second manager continuation picked up the staged branch, verified it, and finished.
- `/dream`'s first real run found its own tracking memory (`project_dream_memory_suite`) had already gone stale within the same day — corrected automatically as part of the run.

### Next session
- All 3 desktop hosts still need a rebuild to pick up the flake bump, the `/dream` suite, `send-results`' fix, and the Discord secret — stacks on the existing pending-switch pile (rebuild-boot/switch split, Meta+G fix, save-memory PR #16, godot dev env, Tailscale MCP connector, etc.).
- A real `/dream` run from the live (post-rebuild) `~/.claude/skills/` symlinks is still untested.

**Commits**: `75addf7`..`2d11999` (4 commits)

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

