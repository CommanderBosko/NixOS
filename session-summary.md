# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-11-03 (session 146) — vpn-server retired

**Focus**: Close the conversation that retired the dead `vpn-server` host and WireGuard hub (PR #92). Its transcript was not in this close's scan, so this is written from the commit message, the diff and the Recent Decisions entry that PR wrote.

### What changed (and why)
- **PR #92 (`5395bb4`, merged `73fd51b`):** removed `hosts/vpn-server/`, `modules/vpn.nix`, the `nixpkgs-stable` and `disko` inputs, gaming's aarch64 binfmt, the `vpn-*` aliases and the wg0 firewall and Pinchflat remnants. Oracle admin-disabled the instance on 2026-08-18 and it never came back; Tailscale and the Proton VPN GUI cover access and egress.
- **Secrets:** the vpn-server sops recipient is gone (`common.yaml` re-keyed), all WireGuard private keys are deleted, and the per-host files for laptop, natalie-laptop and vpn-server are removed.
- **Tooling:** deleted the `vpn-status`, `remote-rebuild` and `new-peer` skills and the vpn data in `hosts.json`; updated about 20 other skills, the README and both CLAUDE.md files.
- **This close:** gaming's live generation is 485 (2026-11-03 07:52, before the retirement), so the removal is not live there. Removed three Known Issues the retirement made false and fixed the `server`-host goal that named `nixpkgs-stable`.

### Decisions
- Remove it entirely rather than leave it commented out as it had been since 2026-08-18: the user no longer plans to use the host, and git history keeps the hub.

### Issues / surprises
- Still on the user: revoke the OCI API key, terminate the instance or tenancy, delete `~/.oci`.
- Not checked: whether Pinchflat still downloads without wg0, and whether Proton's client overrides `/etc/resolv.conf` (pi-hole bypass).

### Next session
- Rebuild gaming (dry-run first) onto the retirement; Oracle cleanup; Waydroid game test; `/fleet-rollout` laptop and natalie-laptop.

**Commits**: `d2559b1..73fd51b` (PR #92, 1 commit)

Secret-scan: clean (tree + 2,012 commits, all 3 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-03 (session 145) — libndk, gate hardening, PRs landed

**Focus**: Close four conversations since the 11-02 close: Waydroid ARM translation, the local `/improve-system` run, review-gate hardening, and merging the open PRs.

### What changed (and why)
- **Waydroid libndk (PR #88, `df50822`):** League Wild Rift showed "won't work for your device" because the image is x86_64; libndk (AMD CPU) was installed with `waydroid_script` by the user, abilist now has arm64. Documented as a comment in `modules/gaming.nix`; imperative on purpose.
- **PR #89 (`78c9638`):** local `/improve-system` via `manager` — misfire-scan fix, gotchas, niri validator, 5 allow entries, new `android-debloat` skill.
- **PR #90 (`13934b0`):** `find-and-check-pr.sh` gate hardened against 8 review gaps, tests first, 3 review rounds, 191/191 tests.
- **Merge:** #89 then #90 merged on "merge anything that looks good", remote branches deleted; a GitHub 503 was a false alarm.

### Decisions
- libndk not libhoudini; keep imperative. Gate fix in its own PR.

### Issues / surprises
- Transcript scan saw only this conversation (counts the close's own invocation as the last run); earlier ones were mined by hand.
- Not verified: Wild Rift install/login. Base-tip race in `ci-gate.sh` remains.

### Next session
- Try Wild Rift; rebuild gaming for global skill edits; Hermes calibrate; `/fleet-rollout`.

**Commits**: `6e2d88b..13934b0` (PRs #88, #89, #90)

Secret-scan: clean (tree + 2,008 commits, all 6 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-02 (session 144) — Landing the package PRs, Waydroid start fix

**Focus**: Close two conversations since the 08:07 close: merge the open package PRs and prune branches, then get Waydroid to actually start on gaming.

### What changed (and why)
- **PRs merged (all small, `evaluate all hosts` green):** #81 `aria2` (`8bfe545`), #83 Waydroid (`ccc8428`), and #85 `unrar` (`eafc290`; the branch had never been pushed, so it went out as a new PR). Six merged `worktree-agent-*` branches deleted; version branches `1.0`-`3.4`/`4.1.3`/`4.2`/`4.2.1` and `fix/pinchflat-ngx` kept on purpose.
- **Waydroid wouldn't start (PR #86, `bf2abda`):** after the rebuild, `waydroid-net.sh` failed with `ip_tables not found`: linux-zen has no legacy `ip_tables` module and `networking.nftables.enable` is false on gaming, so the nixpkgs module kept the iptables-based default package. `virtualisation.waydroid.package = pkgs.waydroid-nftables` fixes it. After the user's `nh os switch` (gen 484, 18:03) the session reached "Android is ready", the `waydroid0` bridge came up and the host pings Android.
- **Research:** ten source reviewers on Waydroid-on-NixOS config; nothing more is needed in Nix. `wl-clipboard` was already on gaming. Saved as memory `reference_waydroid_nixos_research`.
- **GAPPS setup (`b9d5152`):** the image was VANILLA. The imperative steps (`waydroid init -s GAPPS -f`, register the `android_id` with Google) are recorded as a comment in `modules/gaming.nix`.

### Decisions
- Select the nftables package explicitly, not `networking.nftables.enable = true`, which would move the iptables firewall that the Vesktop Proton bypass uses. Keep the image and Google registration imperative (documented, not a oneshot unit).

### Issues / surprises
- gaming's gen 484 came from PR #86's branch; until #86 merges, a rebuild from `main` brings the broken package back. The user asked to land #86 right after this close.
- Not verified: outbound internet from inside Android, any game, the Play Store (Google registration was still pending when the conversation ended).
- The transcript scan only saw this (post-`/clear`) conversation because it counted the close's own first invocation as the "last run"; the two earlier conversations were mined by hand.

### Next session
- Finish Waydroid (Play sign-in, internet, one game); Hermes calibrate chunk 2 and a 2nd baseline; `/fleet-rollout` for laptop, natalie-laptop (now also `aria2`, `unrar`) and vpn-server; gaming disk.

**Commits**: `40e0146..b9d5152` (9 commits: the three package merges, #83, and #86's two commits)

Secret-scan: clean (tree + 1,989 commits, all 6 `secrets/*.yaml` encrypted).

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

