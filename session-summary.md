# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-07-17 — Per-host niri overlay + qBittorrent app-id fix

**Focus**: Split the shared niri config into a common base + per-host overlay so gaming, laptop, and natalie-laptop can each carry their own window rules, then chase down a qBittorrent placement bug the user hit while testing it.

### What changed (and why)
- Split `dotfiles/common/configs/niri-config.kdl` into a shared base (input/layout/binds/standard rules) plus `hosts/<host>/niri-overlay.kdl` per host, pulled in via niri's native `include` directive. Gaming keeps its 7 named-workspace/window-rule monitor pins in its own overlay; laptop and natalie-laptop start with empty overlays and just the standard rules.
- `modules/desktop-environments/niri.nix` gained `osConfig` so it can symlink the right overlay file per host.
- Found and fixed a second, distinct qBittorrent bug: its window rule matched app-id `^qbittorrent$`, but the live window's real app-id is `org.qbittorrent.qBittorrent` — the rule had never actually matched.

### Decisions
- Corrected course mid-task: initially told the user niri's KDL had no include mechanism and proposed Nix-level text concatenation; found `include "dms/outputs.kdl"` already in the live config, which meant a much simpler native-include approach worked instead. Surfaced this and got a fresh go-ahead before implementing.
- Keybinds stay identical across all 3 hosts (shared base); only window rules split, per the user's explicit scoping in the interview.

### Issues / surprises
- The qBittorrent bug looked at first like a tray-restore race (the window had no mapped surface, process alive 7.9h). Live inspection via `niri msg windows`/`niri msg -j workspaces` showed the real cause was a plain wrong app-id in the match regex — worth remembering that "opens on the wrong workspace" symptoms are worth checking against the *live* app-id before assuming a compositor-behavior bug.

### Next session
- Add real content to `hosts/laptop/niri-overlay.kdl` / `hosts/natalie-laptop/niri-overlay.kdl` whenever host-specific rules are wanted (currently empty placeholders).
- Laptop and natalie-laptop still need `rebuild` + reboot to pick up the overlay split and the large pile of previously-pending niri changes (now confirmed live on gaming only).

**Commits**: `3960600..2cbe86c` (2 commits)

---

## Session: 2026-07-16 (session 46) — weekly improve-system cloud routine scheduled

**Focus**: Set up a recurring cloud-scheduled `/improve-system` sweep and worked through what running it unattended actually requires.

### What changed (and why)
- **New cloud routine "Weekly improve-system sweep"** (`trig_01QZPjKtQdMtX5bqwtC8oz8g`) via the `schedule` skill — every Sunday 16:00 UTC (noon Eastern in EDT; drifts to 11am Eastern once EST resumes, cron doesn't auto-adjust for DST). Runs entirely in Anthropic's cloud, no local machine or open Claude Code window required.
- First create attempt hit `HTTP 401` — GitHub account wasn't connected for routines against `CommanderBosko/NixOS`. User installed the Claude GitHub App; retry succeeded.
- **Rewrote the routine's prompt for the cloud sandbox's actual constraints**: `~/.claude/skills/*` slash commands don't exist there (that symlink layer is local Home-Manager state), so the prompt points directly at the repo-relative `SKILL.md` files for `improve-system` and its four repo-managed sub-skills. Also replaces `improve-system`'s interactive `AskUserQuestion` structural gates with a fixed policy (auto-apply low-risk, report-only for structural) since nobody's there to answer on a schedule, and makes the `nixos-dry-run` verification step skip gracefully if `nh`/`nix` aren't installed in the sandbox.
- A concurrent local session (not this conversation) made one small fix, folded in here for accuracy: removed `open-maximized true` from kitty's window-rule (`c0005e0`) per the user's request in that session, keeping kitty's `asus-1` pin. The other four session-45 `open-maximized` rules are untouched.

### Decisions
- Routine opens a PR against `main` rather than pushing directly — first real run of an unattended workflow, wanted a review checkpoint.
- Declined to build a skill for reviewing/merging the weekly PR yet — existing tools already cover the steps, and the routine has never produced real output to design against.

### Issues / surprises
- The GitHub-connection requirement wasn't obvious upfront — routine creation failed outright rather than warning softly, good forcing function to get it connected before the schedule needed it.

### Next session
- Check https://claude.ai/code/routines/trig_01QZPjKtQdMtX5bqwtC8oz8g after 2026-07-19 for the first real run and whatever PR it opens.
- Same pending gaming/laptop reboot as prior sessions — now also covers the kitty rule reversion alongside the other four `open-maximized` rules.

**Commits**: `c0005e0` + session-close (2 commits)

---

## Session: 2026-07-16 (session 45) — qBittorrent autostart-race bug fixed, open-maximized rules added, new fullscreen-rule skill

**Focus**: Chased down why qBittorrent kept opening on the wrong workspace despite a correct window-rule, added fullscreen-on-open to five apps, then closed the loop with a new sibling skill and a dry-run gotcha.

### What changed (and why)
- **qBittorrent workspace bug root-caused**: the session-44 window-rule was already correct (`StartupWMClass=qbittorrent` matches it exactly) — the real cause was qBittorrent's own "run on startup" preference, which autostarted it ~12s before Mod+G. Being single-instance, Mod+G's `qbittorrent &` just raised that already-misplaced window instead of creating a fresh one the rule could act on. Fixed live: stopped `app-org.qbittorrent.qBittorrent@autostart.service` and removed the autostart `.desktop` file (backed up, not deleted) — outside the nix flake, already in effect, no reboot needed.
- **`open-maximized true` added to 5 window-rules** (Kitty, Vesktop, Zen Browser, Deezer, qBittorrent) so they launch already-maximized, same as pressing Mod+F. Added the same rule to Steam too, then reverted it per the user's explicit follow-up request.
- **New `add-niri-fullscreen-rule` skill** (project-local, `/skill-suggestion` → `/new-skill`) — sibling of `add-niri-window-rule`, scoped to just `open-maximized true`. Carries forward this session's two gotchas: Steam-style multi-window-one-app-id apps vs. per-game app-ids with no blanket rule possible, and the autostart-vs-single-instance trap.
- **`nixos-dry-run` gained a Gotchas section** (`/skill-upgrade`) — its TUI output buries the useful summary at the end; documented `tail -8` / a targeted grep instead of guessing a tail length.

### Decisions
- Disabled qBittorrent's autostart entirely rather than patching around it — no window-rule edit could fix a race against the app's own pre-existing single-instance window.
- Kept `add-niri-fullscreen-rule` as its own skill rather than extending `add-niri-window-rule` — different single-purpose property (`open-maximized` vs. `open-on-workspace`/`open-on-output`), same single-responsibility bucket rule as its sibling pair.

### Issues / surprises
- The qBittorrent bug looked at first like a simple app-id mismatch (same shape as a normal window-rule miss) but turned out to be a login-autostart race — worth remembering for any other single-instance app that seems to ignore a window-rule.
- Own mistake mid-session: a `mv` meant for the scratchpad landed in the repo's `.claude/` directory instead (path typo); caught immediately via `git status` and moved to the correct location before anything was staged.

### Next session
- Same pending gaming/laptop reboot as sessions 43-44, now also covering the 5 new `open-maximized` rules — see Next Steps in `project-state.md`.
- qBittorrent's autostart fix is already live on gaming; nothing pending there.

**Commits**: session-close only (1 commit)

---

## Session: 2026-07-16 (session 44) — financeguru bump, Deezer/qBittorrent monitor pins, new window-rule skill, Mod+G full-setup launcher

**Focus**: Continuation of the same day's work — bumped one flake input, extended the per-monitor window-rule pattern to two more apps, shipped a proper skill for that pattern after doing it twice by hand, then expanded the Mod+G keybind into a full initial-setup launcher.

### What changed (and why)
- **`financeguru` bumped** (`d35c5d2`, via `/bump-input`): `50335413` → `652a706b`, verified with a clean dry-run before committing.
- **Deezer pinned to a new `dell-3` workspace slot** (`c3990a4`) — same pattern as session 43's batch of per-monitor rules, done by hand since no dedicated skill existed yet.
- **New `add-niri-window-rule` skill** (`e9af675`, via `/ship-skill`): user pointed out this exact workflow (standalone "pin X to monitor Y", no keybind involved) had now been done twice by hand with no skill covering it — `add-niri-keybind` only covers window rules tied to a *new keybind*. Built the sibling skill, cross-referenced both so future requests route correctly. Smoke-tested for real: asked it to pin qBittorrent to the Asus monitor, all 3 Asus slots were already full, so it correctly flagged the conflict via `AskUserQuestion` instead of double-booking — redirected to a new `dell-4` slot on the Dell monitor instead, confirmed, and kept as a real change (not reverted after the test).
- **`Mod+G` expanded into a 7-app full-setup launcher** (`b635287`) — from "Steam, Lutris, Vesktop" to kitty/steam/lutris/vesktop/zen/deezer/qbittorrent, one shell-spawned bind. Every app already had a monitor pin from this session's work, so the single keybind now spreads the whole setup across both of gaming's outputs.

### Decisions
- Kept the smoke test's real side effect (qBittorrent→`dell-4`) rather than treating it as throwaway, since the user explicitly confirmed it during the test.
- Kept `add-niri-window-rule` as a separate skill from `add-niri-keybind` rather than merging them — different trigger, same verification steps, cross-referenced instead of duplicated.

### Issues / surprises
- None — straightforward extension of session 43's work, no dead ends.

### Next session
- Same pending item as session 43: **gaming + laptop rebuild + reboot** to pick up everything from both sessions (`4211a36`..`b635287`) — verify Mod+G launches all 7 apps spread correctly across both monitors.

**Commits**: `d35c5d2`..`b635287` (4 commits)

---

## Session: 2026-07-16 (session 43) — Niri keybinds/window rules, kdeglobals fix, flake bump, improve-system sweep

**Focus**: A grab-bag session — new niri keybinds and per-monitor window rules, a real kdeglobals theming bug found and fixed, a full flake-input bump with an insecure-package waiver swap, and an `/improve-system` maintenance pass.

### What changed (and why)
- **Niri keybinds**: Mod+G launches Steam, Lutris, and Vesktop together (one keybind, multiple spawns); Mod+E opens dolphin.
- **Per-monitor window rules** (`3be13bb`): on gaming's two outputs, kitty/steam/lutris pin to the Asus monitor (`DP-1`), vesktop/zen browser pin to the Dell monitor (`HDMI-A-1`) — user asked for niri's equivalent of Hyprland window rules, specified the exact app-to-monitor mapping wanted.
- **kdeglobals bug fixed** (`4a92d59`): the `ColorScheme` write only fired when `XDG_CURRENT_DESKTOP=niri` was already set at HM-activation time — true only for an interactive live-session switch, never for this repo's real workflow (`nh os boot` + reboot, which activates before any session exists). Confirmed via journalctl. Removed the guard entirely.
- **Flake bump** (`bacec40`): dms, financeguru, home-manager, nixpkgs — verified via flake-check + deep-eval across all 4 hosts.
- **Insecure-package waiver swapped** (`6760838`): pnpm-10.29.2's CVE fix landed upstream (vesktop builds against generic `pnpm_10` now), so that waiver was removed; the same nixpkgs bump flagged `electron-40.10.5` (vesktop's runtime, EOL) insecure, so a new waiver was added for it instead — same mechanism, same "retest at next bump" removal condition.
- **`/improve-system` sweep** (`7c445c5`, `8060832`): new project-local `add-niri-keybind` skill; a `flake-update-verify` gotcha from the waiver-swap incident; `skill-audit` over all 54 skills (4 parallel sub-agents) found zero drift against `hosts.json`/`vpn.nix` — applied low-risk fixes (missing `## Arguments` sections, script extractions for `deep-eval-check`/`verify-service`/`git-commit`); `improve-system`'s new-skill handoff gained a smoke-test step.

### Decisions
- Electron waiver confirmed safe by the user before adding, mirroring the pnpm waiver's precedent.
- `improve-system` borrows just `ship-skill`'s smoke-test step rather than switching its new-skill handoff to `ship-skill` outright — keeps one consolidated end-of-run commit instead of fragmenting into `ship-skill`'s per-skill commit+push-confirm flow.
- kdeglobals write made unconditional rather than fixing the guard's condition — a real Plasma session re-applies its own scheme on login anyway, so the guard added no value.

### Issues / surprises
- The kdeglobals guard bug is a good example of "tested only interactively, broken in the real deploy path" — the condition was never actually exercised by this repo's `nh os boot`-then-reboot workflow, so it silently no-op'd since it was written.

### Next session
- **gaming + laptop: rebuild + reboot** to pick up this session's keybinds, window rules, kdeglobals fix, and flake bump. Verify Mod+G/Mod+E, the per-monitor placement on gaming, and that dolphin renders dark without an interactive switch first.

**Commits**: `4211a36`..`8060832` (8 commits)

---

