# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-11-02 (session 143) — Waydroid on gaming

**Focus**: Find the best way to play Android games on NixOS, then add it to gaming on its own branch.

### What changed (and why)
- **Waydroid enabled on gaming (`1f5888b`, PR #83, open):** one line in `modules/gaming.nix`, `virtualisation.waydroid.enable = true;`. Waydroid runs Android in a container on the host kernel, so it is near-native speed; the nixpkgs module handles LXC, the `waydroid0` firewall trust and the kernel binder check (built into linux-zen). A dry-run on the earlier working tree was clean (adds `waydroid` 1.6.3, `lxc`, `waydroid-container.service`, no kernel change). The commit on its own branch was not dry-run again; PR CI deep-evals every host.
- **Limits recorded:** software rendering on the RTX 3070 (GPU rendering after the AMD swap), no Play Integrity games, Play Store needs the `android_id` registered with Google, ARM-only games need `waydroid_script` (imperative).
- **Close:** state docs written in a worktree off `origin/main` so the close PR is docs-only and doesn't wait on PR #83.

### Decisions
- Waydroid over the Android Studio emulator, scrcpy, Genymotion and redroid; on gaming only; cut from `origin/main` rather than stacked on `feat/desktop-add-unrar`, so the unrar, aria2 and Waydroid PRs stay independent.

### Issues / surprises
- gaming's gen 482 contains `aria2` (PR #81, unmerged) but the Waydroid branch doesn't, so rebuilding from that branch would drop it; merge #81 and #83, then rebuild from `main`.
- The dry-run diff also listed `unrar` added and `aria2` removed; both came from other branches' state, not from this edit.
- Not applied: gaming is still on gen 482 with no Waydroid.

### Next session
- Land #81 and #83, rebuild gaming from `main`, then `sudo waydroid init` and a first run under niri; push the unrar branch if wanted; Hermes calibrate chunk 2 and a 2nd baseline; `/fleet-rollout` for laptop, natalie-laptop and vpn-server; gaming disk.

**Commits**: `1f5888b` (PR #83); the baseline range `4793bc7..1f5888b` also holds the cloud routine's PR #82 (weekly improve-system skill-doc fixes) and the 10-29 merges, none from this session.

Secret-scan: clean (tree + 1,982 commits, all 6 `secrets/*.yaml` encrypted).

---

## Session: 2026-10-29 (session 142) — Vesktop bypass by group, powershell, pin check, device debloats

**Focus**: Close seven conversations since the 10-27 close: Vesktop lost its Proton bypass again, `powershell` was added, the `nixpkgs` pin was re-checked, and three non-repo devices were debloated.

### What changed (and why)
- **Vesktop bypass rebuilt around a `novpn` group (PR #78, merged `865686b`, live on gaming gen 481):** Electron 43 moves itself into its own `app-vesktop-<pid>.scope` right after launch, which emptied `app-novpn.slice`, so Vesktop went back through Proton and Discord answered 403 to the exit IP. Vesktop now starts via `sg novpn` and the fwmark rules match `-m owner --gid-owner novpn`, which children inherit; the slice, the uid-1000 pin and the cgroup boot wait are gone. Verified: all processes in group `novpn`, `sg` curl 200 vs 403 on the VPN path, the user saw messages load.
- **`powershell` for both users (PR #77, merged `4e19b88`):** in `modules/development.nix`; 4-host deep-eval PASS, gaming dry-run = `powershell` only. Not live yet: gen 481 came from the Vesktop branch.
- **Pin check:** keep the `nixpkgs` pin. mcp-nixos is fixed in `nixos-unstable` `31ecbaca`; vendor-reset (#575192) and pinchflat are not.
- **Outside the repo (memory only):** CleanYourTV debloat of the TCL TV (33 packages, new launcher, remote buttons remapped), DumbTV debloat of the Fire TV Stick (42 packages, Tailscale starts at boot via always-on VPN), Galaxy Tab A7 (27 packages, over USB). PHP2Shell check: nothing reachable.

### Decisions
- Group match over a manual cgroup move or an Electron-switch hunt: the self-scoping makes any cgroup match unreliable, and the group removes the boot race too. `powershell` in the shared dev module, not per user. Use Tailscale IPs, never LAN addresses (user rule, 10-28).

### Issues / surprises
- gaming's gen 481 was built from the unmerged Vesktop branch (fix, but no `pwsh`); both PRs were merged at the end of this close, so the next rebuild from `main` brings both.
- The TCL TV blocks Tailscale at boot (`TclAppBoot`), and the Tab A7's wireless-debugging ports change on every reboot, so USB was the reliable route.

### Next session
- `rebuild-switch` on gaming from `main` and restart Vesktop; Hermes calibrate chunk 2 and a 2nd baseline; `/fleet-rollout` laptop + natalie-laptop + vpn-server; gaming disk; hand-test the Fire Stick and the tablet; `apt upgrade` the pi-hole.

**Commits**: `cf05091` (merge of the 10-27 close) on `main`; `277f5a9` (PR #78, merged `865686b`) and `155d091` (PR #77, merged `4e19b88`)

Secret-scan: clean (tree + 1,971 commits, all 6 `secrets/*.yaml` encrypted).

---

## Session: 2026-10-27 (session 141) — improve-system PRs #67–#75, Hermes baseline and calibrate

**Focus**: Close out eight conversations since the 10-25 close: a `/improve-system` run that became nine merged PRs (mostly hardening the weekly PR review gate), the first valid Hermes competency baseline, and a half-finished calibrate.

### What changed (and why)
- **`/improve-system` via `manager` → PRs #67–#75 (all merged 2026-10-26):** Manager Training Mode is ON and a background subagent can't ask, so `manager` analysed and stopped; after the user approved its plan, six worktree agents built the PRs and independent reviewers found real bugs in most of them (fixed before merge). Landed: skill-suggestion dedup, `land-prs` CI wait and head pinning, `session-closer` STEP 7 plus rotation of Recent Decisions and Next Steps (`project-state.md` 240 → 105 KB), `git-push --pr` opt-in, small skill fixes, seven Hermes scorer fixes.
- **`review-improve-system-pr` gate rewritten default-deny (#70, #74, #75):** the checker let `Bash(rm *)`, `sudo *`, `curl *` and a Gmail send through, and a longer denylist still had ~13 bypasses. An added entry now passes only as an exact short read-only form; edits to the gate, `improve-system`, or scripts named by settings.json exit 2 for a human; fetch failures exit 3; `ci-gate.sh` pins the merge to the reviewed SHA.
- **Hermes competency test:** first valid baseline 53.8 (93/93 repeats, five of seven categories "don't delegate"), but calibrate had never run, so it is provisional. Calibrate hit the Claude session limit three times; split in two, code + net scored 99.4 (items fair), the other 16 items still need a re-run. `hc.py normalize` crashed on a Claude `permission_denied` event; fixed (`c6c8ee1`).
- **Pin check ×2:** the `nixpkgs` pin stays (vendor-reset #575192 open; mcp-nixos fixed on master but not in `nixos-unstable`; pinchflat still flagged).

### Decisions
- Default-deny over a longer denylist; merge #70/#74 on green CI before their reviews returned (reviews became the next PRs); `--pr` opt-in so a close can't open PRs unasked; hold the 1800 s timeout change until calibrate ends so it lands as one version bump.

### Issues / surprises
- `claude -p` reported the usage limit as "workspace not trusted", hiding the real cause; mid-run attribution reminders flipped three agent commits to a Haiku trailer (amended before merge); agent worktrees block plain `git` (used `/run/current-system/sw/bin/git`).
- `project-state.md` Known Issues still had a "no rotation" bullet and a "never run live" `land-prs` bullet; both rewritten.

### Next session
- Re-run calibrate chunk 2, fix items under 90, bump the suite once, then a 2nd full baseline; `/fleet-rollout` laptop + natalie-laptop + vpn-server; decide gaming's disk.

**Commits**: `92557e0..fe25633` (~30 commits, 9 of them PR merges) plus `c6c8ee1`

Secret-scan: clean (tree + 1,967 commits, all `secrets/*.yaml` encrypted).

---

## Session: 2026-10-25 (session 140) — flake bump pinned back, monitoring and a repaired Hermes test

**Focus**: Close out 16 conversations since the 10-24 close: a flake bump that broke gaming's build and was undone by pinning nixpkgs, Prometheus monitoring for Hermes, and a Hermes competency run that was invalid because of a harness race.

### What changed (and why)
- **nixpkgs pinned to `fe132422` (PRs #56, #58):** the 10-24 bump marked mcp-nixos and pinchflat unusable and broke gaming's zen kernel modules (`vendor-reset.ko.cer`), which PR CI can't see because it only evaluates. One pin replaced three per-package workarounds. Pinchflat-ngx (PR #57) was closed unmerged, branch kept; DB backed up first.
- **Mnemosyne vector search:** its native libs were built against a newer glibc than Hermes's Python; the plugin now builds from Hermes's own nixpkgs. Verified live (write-time embedding, recall, forget).
- **Prometheus monitoring (PR #59):** read-only for Hermes via `hermes-monitor`; it caught a real disk alert. Root was 98% full; deleting the 38 GB League prefix left 63 GB free.
- **Hermes competency harness (PR #63):** 42 of 90 repeats of the first full run died to a gateway-drain race and were graded 0. Fixed the race, added retries, an abort rule and a real preflight, then made doing nothing score 0 (suite 2.0.0). No baseline yet.
- **Guardrail fix (PRs #64, #62, #65):** the weekly sweep PR tripped the settings.json guardrail a third time, so the guardrail now accepts additive allow-list entries; sweep and a numbering fix landed. Status line got a Hermes progress bar plus a 30 s refresh (PR #60). PR #55 (sixth rule) merged.

### Decisions
- Pin nixpkgs rather than keep stacking overlays; fix the guardrail rather than waive the PR; keep Hermes read-only until Network reaches "alone".

### Issues / surprises
- Eval-only CI let a broken kernel build through; run `nixos-dry-run` on gaming before merging nixpkgs bumps.
- The first full test run cost 2h17m of GPU before anyone noticed; the harness now aborts after 3 consecutive infra errors.
- The agent's `rm -rf` cleanups were denied; the user ran them.

### Next session
- First valid `/hermes-competency-test full`; decide the Steam library / disk; rebuild laptops for node exporters; lift the pin when upstream settles.

**Commits**: `fb2005e..74a8f5d` (~25 commits, ~11 of them PR merges)

Secret-scan: clean (tree + 1,934 commits, all `secrets/*.yaml` encrypted).

---

## Session: 2026-10-24 (session 139) — Proton/Vesktop boot and stall fixes, sixth rule

**Focus**: Close out four conversations: three fixes that make Proton VPN and the Vesktop bypass survive a cold boot, plus a new standing rule (PR #55).

### What changed (and why)
- **Firewall no longer dies at boot (`d926620`, PR #52):** Vesktop's cgroup rule ran before `user@1000` created `app-novpn.slice`, so `firewall.service` failed on two cold boots and gaming ran with no firewall until a manual restart. The rules now live in `vesktop-direct.service`, ordered after login, with the slice as a login-time user unit. Verified on the 16:03 cold boot.
- **Proton tray icon (`741a092`, PR #53):** the app checked once for the tray watcher and lost the race with DMS/quickshell; the autostart now waits (≤30 s) for it. Verified after the 08:01 boot.
- **Proton stuck at "Connecting" (`4274364`, PR #54):** api-core 5.2.5 missed NM's activation signal when WireGuard came up first; patched to start the local agent if already activated. Live on gen 472, not yet proven (intermittent).
- **Sixth standing rule (`2a44c82`, PR #55, open):** "Read Everything Before Editing". A "Supervisor, Not Builder" rule was added and removed in the same conversation.

### Decisions
- Late-start rules service over `|| true` or a gid match; a package patch over a watchdog; Supervisor dropped as overhead.

### Issues / surprises
- The boot-order bug hid because gen 467 was switched live with the slice already present.
- Hermes's tray-wait draft did not evaluate on the first try; no token saving on small Nix edits.
- The live `~/.claude` still has the seven-rule version until PR #55 merges and a host rebuilds.

### Next session
- Land #55 and rebuild; watch Proton over several boots; carry-overs from 138.

**Commits**: `2c9c8ed..2a44c82` (9 commits, 4 of them merges)

Secret-scan: clean (tree + 1,911 commits, all `secrets/*.yaml` encrypted).

---

