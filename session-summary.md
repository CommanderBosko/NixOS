# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-07-18 — Skill model/script paradigm rollout; two real cross-host bugs found

**Focus**: Classify all 52 skills by grunt-vs-judgment work and pin cheap ones to Haiku, run a scoped skill-audit for deterministic work that belongs in scripts, then chase down two real bugs the audit's own verification work surfaced along the way.

### What changed (and why)
- Classified all 52 skills as grunt (haiku) or judgment (keep top model) via 4 parallel sub-agents; pinned `model: haiku` on the 32 grunt-work skills. Confirmed `SKILL.md`'s `model:` frontmatter field is real and documented. Taught `new-skill`/`create-loop` to apply this to every future skill.
- Ran `/skill-audit` scoped to just its "deterministic work → scripts/" lens across all 52 skills — 13 findings, implemented 11 across 6 commits: a new shared `.claude/lib/resolve-host.sh` (de-duping `ssh-host`+`journal`), plus script extractions for `session-closer`, `ci-status`, `add-secret`, `pin-input`, `vpn-status`, `switch-de`, `new-peer`, `de-smoke-check`, `add-default-app`. Every script proven against live state before being wired in. Taught `new-skill` to apply this to every future skill too.
- `switch-de`'s brand-new `current-de.sh` immediately caught a real bug: `natalie-laptop` still imported both `niri.nix` and `plasma.nix` (a leftover SDDM dual-session setup from session 42 that was never actually used) — dropped Plasma, niri-only now.
- The same sweep's `deep-eval-check` run caught a second, unrelated real bug: `vpn-server`'s flake eval has been broken since the prior session's `rtk` install — `rtk` only exists in nixpkgs-unstable, not the `nixpkgs-25.11` stable channel `vpn-server` pins. Fixed by gating the package and its Claude Code hook on `pkgs ? rtk` instead of hardcoding it.
- Built `shared-module-check` (new skill) to close the exact gap that let the `vpn-server` bug through — forces a 4-host sweep after any shared-module edit instead of trusting a local dry-run.
- Found and fixed a bug in the *very script written earlier this session*: `session-closer`'s new `scan-session.sh` used `git log --all` in its range query, which pulls in stash entries and unrelated branch history — the classic already-documented `--all` footgun, reproduced because the sub-agent that wrote it didn't have access to that memory.

### Decisions
- `vpn-server`'s fix stays unstable-only, not force-installed some other way — user explicitly held off deploying until nixpkgs-25.11 catches up naturally; the existence-guard is the right shape either way.
- Desktop-host rebuilds (gaming/laptop/natalie-laptop) left to the user — they said they'd handle those three themselves.
- Skipped Tier 4 of the skill-audit findings (a `claude-rules` grep script, `new-skill`'s scope-detection mechanics) — both global skills, both too small a payoff for the symlink+rebuild overhead.

### Issues / surprises
- Two real, previously-undetected bugs (`natalie-laptop`'s stale dual-DE import, `vpn-server`'s broken eval) surfaced purely as side effects of building better verification tooling — neither was what the session set out to find. `vpn-server`'s break had been sitting undetected since a prior session's commit, exactly because that commit's own dry-run only exercised the local host.
- The new `scan-session.sh` script had a real bug on its very first real-world run (this close) — a reminder that a freshly-forked sub-agent writing a script has no access to hard-won repo-specific gotchas already sitting in memory.

### Next session
- Push all of this session's commits (session-closer handles that now).
- Check whether `vpn-server` needs anything once a `nixpkgs-25.11` point release ships `rtk` — otherwise no action needed.
- User is doing the gaming/laptop/natalie-laptop rebuilds themselves; nothing to chase from this side until that's done.

**Commits**: `8222fb5..8507de3` (12 commits, this session)

---

## Session: 2026-07-17 — Declarative default apps, then off KDE entirely; two live bugs root-caused

**Focus**: Set up declarative default-application associations, hit a wall with KDE apps being unreliable under niri (no `kded6`), swapped the whole stack for lightweight alternatives, then chased down two unrelated live bugs the user hit (broken AppArmor reload, USB not auto-mounting).

### What changed (and why)
- `xdg.mimeApps.defaultApplications` in `home.nix`: Kate/Ark/Okular/Gwenview/VLC, every mimetype verified against each app's real `.desktop` file. First rebuild failed activation (`mimeapps.list` clobber) — fixed with `force = true`, and preserved real working associations (GitHub Desktop OAuth, Discord/FreeTube/r2modman handlers) found in the live file before it got overwritten.
- Dolphin's "Open With" picker turned out fundamentally broken under niri — KDE's `ksycoca` app database needs `kded6` to stay valid, which niri never runs. Confirmed via `xdg-open` working while Dolphin's own picker stayed empty even after clearing caches and a genuinely fresh process. Drafted a `kded6` systemd service as a fix, but the user chose to drop KDE apps entirely instead: Thunar, xarchiver, zathura, imv replaced Dolphin/Ark/Okular/Gwenview/Double Commander. Net -123 MiB.
- Built `add-default-app` skill for the now-repeated "verify real mimetypes, add to xdg.mimeApps, verify the generated file" workflow — shipped untested at first, which led to `new-skill` gaining a permanent reminder to flag untested output and point at `ship-skill`.
- Fixed three niri skills (`add-niri-window-rule`, `add-niri-keybind`, `add-niri-fullscreen-rule`) that still pointed at the old shared `niri-config.kdl` location, stale since the per-host overlay split.
- Root-caused two live bugs: USB drives not auto-mounting under Thunar (needed `gvfs`+`thunar-volman`, since Dolphin's KIO backend never needed them), and `nh os boot` failing outright with "Failed to reload apparmor.service" (a real nixpkgs bug in `apparmor-parser-5.0.0` missing a file its own `aa-remove-unknown` script expects — worked around via `reloadIfChanged = false`).

### Decisions
- Chose to fully swap off KDE apps rather than keep patching around the missing `kded6` session — this was the third time in one session that gap caused a real bug (Dolphin's picker, Ark's in-archive file-open, and the underlying `ksycoca` staleness itself).
- `new-skill` gets a reminder line, not a built-in smoke test — keeps it a clean single-bucket Utility skill; `ship-skill` already owns verification.

### Issues / surprises
- Even after `gvfs`/`thunar-volman` built and activated successfully, USB auto-mount still didn't work — turned out to be session-level staleness (the user's `dbus-broker.service` hadn't restarted since login, so it never picked up gvfs's new D-Bus service registration). Same root-cause *shape* as the `ksycoca` issue: live activation doesn't always restart the daemons that only read their config once at startup. Worth remembering as a pattern for future "config is right but nothing works" reports.

### Next session
- Push commit `c4690e5` (apparmor fix) — everything else this session is already pushed.
- Reboot gaming (or restart the session D-Bus daemon) to actually fix USB auto-mount.
- laptop + natalie-laptop still need their own rebuild to pick up this session's app-stack swap plus the whole accumulated backlog since session 34.

**Commits**: `4b2e188..c4690e5` (11 commits)

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

