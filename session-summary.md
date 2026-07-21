# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-07-20 (continued) — Fixed all 6 structural findings from the routine's first clean run

**Focus**: Fix the 6 minor skill-audit findings the improve-system routine's own first clean run (see the entry directly below) surfaced but didn't auto-apply, since they were flagged structural/report-only.

### What changed (and why)
- `de-smoke-check` + `public-repo-guard`: converted free-prose pick-one/confirm gates to the **AskUserQuestion tool**, matching the existing pattern in `bump-input`/`nixos-gc`/`rollback`/`pin-input` — a hard pick beats an ambiguous typed reply, especially for `public-repo-guard`'s baseline-append gate (permanently records a finding as intentional).
- `shared-module-check`: added the `## Arguments` section it was missing, modeled on `verify-service`.
- `create-loop`: extracted Step 4's mechanical structural checks into `scripts/lint-loop.sh`, keeping only the genuinely judgment-based checks (are done-rules measurable, does a verification pass resolve) in prose. Smoke-tested against two real generated loops before wiring it in.
- `skill-suggestion`: rather than give it its own copy of transcript-dir-resolution logic that two other skills already had scripted, built a new shared `dotfiles/bosko/claude/skills/lib/` location (mirrors the project-local `.claude/lib/` convention) and rewired all three skills (`skill-suggestion`, `skill-upgrade`, `session-closer`) to call the one shared script — closing the duplication everywhere instead of adding a fourth instance of it. Required a new `bosko-claude.nix` `home.file` entry.
- `skill-upgrade`: its own Gotchas-append confirm gate also converted to AskUserQuestion.
- Considered spawning parallel sub-agents for the 6 independent fixes (per the repo's standing parallelization rule) but judged direct execution faster here: all the necessary repo-convention research (recursive vs. single-file skill symlinks, the AskUserQuestion confirm-gate pattern, the shared-lib precedent) was already gathered in-context from reading the six target files plus four reference skills before editing began, so fresh agents would have needed the same context re-explained rather than saving any real time.

### Decisions
- See `project-state.md` Recent Decisions for the full writeup of the `lib/` extraction scope decision (touching two already-stable scripts beyond what the finding literally asked for).

### Issues / surprises
- Testing the rewired `find-skill-misfires.sh` against this repo's own transcripts immediately caught a real, live misfire from earlier in this very session (an `rtk`-intercepted `find -o` compound-predicate failure) — a nice unplanned confirmation that the dedup didn't break the script's actual detection behavior.

### Next session
- None — all 6 findings closed, verified (`nixos-dry-run` + 4-host `shared-module-check` sweep, all PASS), committed, and pushed.

**Commits**: `29e40c1` (1 commit)

---

## Session: 2026-07-20 — Found and fixed the improve-system cloud routine's root cause: GitHub App never installed

**Focus**: Follow up on the prior session's unresolved third redesign of the "improve-system" cloud routine — determine why it was still producing zero trace on GitHub even after the checkpoint-issue redesign.

### What changed (and why)
- Re-checked the routine ~20h after its 2026-07-20 00:58 UTC fire: `RemoteTrigger get` confirmed it had run, but `gh issue list`/`gh pr list` were still completely empty — meaning even the routine's literal first action (`gh issue create`) never reached GitHub. Ruled out a mid-run hang; this pointed at an infra/auth problem, not a prompt-design flaw.
- Walked the user through GitHub's settings UI to trace the actual permission gap: the "Claude" GitHub App (owned by `anthropics`) was **authorized** on the user's GitHub account (visible under Authorized GitHub Apps, Issues/PRs permissions listed) but had **zero installations** — absent from Installed GitHub Apps entirely. GitHub Apps require both authorization and installation independently; authorization alone grants no repo access.
- User installed the app at `github.com/apps/claude`, scoped to `CommanderBosko/NixOS`, with Contents/Issues/Pull-requests read & write.
- Re-triggered the routine via `RemoteTrigger run` to verify. Tracking issue [`#1`](https://github.com/CommanderBosko/NixOS/issues/1) was created within 15 seconds, all 6 checkpoints posted, issue closed with a full report ~90 seconds later — the routine's first-ever clean end-to-end run. Zero-diff (nothing needed applying); 6 minor structural findings logged for manual review only.
- No changes landed in this repo — all work this session was diagnostic (GitHub UI + `RemoteTrigger`/`gh` API calls), outside git entirely.

### Decisions
- See `project-state.md` Recent Decisions for the full writeup of the diagnostic trail and why the App-install fix was the right call (confirms sessions 46/51's prompt-design work was correct all along — the blocker was entirely infra-side).

### Issues / surprises
- `WebFetch` on the routine's own `claude.ai/code/routines/<id>` page still 403s (no login session available to a Claude Code tool) — GitHub remained the only reachable diagnostic channel, and this time it actually held the answer once the right settings tab was checked (Authorized GitHub Apps vs. Installed GitHub Apps are easy to conflate — the Connectors page in claude.ai showing "GitHub Integration" as connected was misleading, since that reflects authorization only).

### Next session
- None — routine confirmed working, back on normal weekly cadence. Only revisit if a future Sunday run goes silent again.
- 6 minor skill-audit findings from the routine's own run are logged in `project-state.md` Current Goals for whenever there's appetite to work through them (all low-priority polish, none urgent).

**Commits**: none (diagnostic-only session, no repo changes)

---

## Session: 2026-07-19 — Diagnosed and redesigned the silent "improve-system" cloud routine

**Focus**: Review the PR the scheduled weekly `improve-system` cloud routine was supposed to have opened, discover it opened nothing at all, and fix the routine so a future run can't fail silently again.

### What changed (and why)
- Found the routine (`trig_01QZPjKtQdMtX5bqwtC8oz8g`, weekly Sunday cron) had fired once already with zero trace on GitHub — no PR, no branch, no issue — and `persist_session:false` meant its session transcript was discarded, so "ran clean" and "failed silently" were indistinguishable from outside.
- Flipped `persist_session:true` and re-ran. Watched via a local background `gh pr/issue list` poller for 78 minutes total (two watches, 30 then 45 min) — still nothing. Concluded the original design's fatal flaw: it only ever writes anything to GitHub as its very last action, so a mid-run hang looks identical to a clean pass.
- Redesigned the routine's prompt: it now opens a GitHub tracking issue (`improve-system weekly report — YYYY-MM-DD`) as its literal first action, posts a checkpoint comment after each of its 6 steps, and only closes the issue as the final action. Triggered a third run (2026-07-20 00:58 UTC) under this design; ended the session before it resolved.
- No changes landed in this repo itself this session (working tree stayed clean throughout) — all work was against the cloud routine's config via the `RemoteTrigger` API, which lives outside git.

### Decisions
- See `project-state.md` Recent Decisions for the full writeup of why each fix step was chosen (persist_session first, then the checkpoint-issue redesign after that alone proved insufficient).

### Issues / surprises
- `WebFetch` 403s on `claude.ai/code/routines/<id>` — no way to check a routine's live run status except via the browser UI (real login) or by having the routine itself leave a trail on GitHub.
- The `RemoteTrigger` API exposes trigger *config* (get/list/create/update/run) but no run/session *status* — there's no way to ask "is this run still going" short of watching for its side effects.

### Next session
- Check `gh issue list --state all` on `CommanderBosko/NixOS` for `improve-system weekly report — 2026-07-20` first thing — its state (open/closed) and checkpoints tell you exactly what happened to the third run.
- If it's still silent even with the new design, suspect the cloud sandbox lacks `gh` write access entirely and investigate the environment's GitHub App/token scope directly.

**Commits**: none this session (repo untouched; all changes were to the cloud routine's config)

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

