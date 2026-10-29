# Project State Archive — Next Steps

Older `Next Steps` session blocks rotated out of [project-state.md](project-state.md) by session-closer, most recent first. Git history holds every pre-rotation version of that file.

**Session 137 next steps:**
1. ~~`land-prs` PR #47 and PR #48~~ — **DONE session 138** (`3c16bbe`, `cdc8b87`); then pull + rebuild laptop and natalie-laptop (`rebuild-host`), sign in to Proton once per user, set Auto connect = `Fastest`.
2. On gaming with Proton connected: confirm `resolvectl`/`/etc/resolv.conf` still reach the pi-hole through Tailscale and `tailscale status` stays healthy; confirm Vesktop still loads after the next rebuild (restart it first).
3. Ask what the phone's Proton app shows if the no-connectivity problem recurs.
4. Session 136's list and session 135's open items are restated in the session 141 block above (their blocks are in the archive).

**Session 136 next steps:**
1. ~~`land-prs` PR #47 (Proton VPN) and PR #48 (`rebuild-host`)~~ — **DONE session 138**; then rebuild each desktop and, on gaming, connect Proton VPN and check `resolvectl`/`/etc/resolv.conf` (pi-hole DNS leak?) and `tailscale status`.
2. After gaming is rebuilt (PR #48 landed and live on gaming as of gen 468, session 138), try `rebuild-host natalie-laptop` for real; it replaces the alias.
3. Session 135's open items, restated here because that block is now in `project-state-next-steps-archive.md` (its `land-prs` of #44 is done): `/hermes-competency-test calibrate` the week of 10-26, then `full` twice after `llm-on`; `/fleet-rollout` laptop + natalie-laptop (whole backlog incl. the 10-18 flake bump), then uninstall Superpowers/Ponytail there if present. Optional: the Hermes toolset-pruning decision; ask Hermes to list the inbox (last 10-19 checklist item); delete `~/.hermes/backups/mnemosyne-fix-20261020/` and the competency-test leftovers (see Known Issues); `/improve-memory` to shrink `MEMORY.md`.

**Session 135 next steps:**
1. `land-prs`: merge PR #44 (competency test, CI green) and this close's docs PR.
2. Week of 10-26: `/hermes-competency-test calibrate`, then `full` twice (after `llm-on`). See Current Goals.
3. `/fleet-rollout` laptop + natalie-laptop (whole backlog incl. the 10-18 flake bump), then uninstall Superpowers/Ponytail there if present.
4. Optional: Hermes toolset-pruning decision; ask Hermes to list the inbox (last 10-19 checklist item); delete competency-test leftovers (`runs/20261020-190620-custom-hermes` 161 MB, `runs/20261020-200711-full-claude`, `keys/res-0{1,2,3}/__pycache__`, `~/projects/hermes-tests/competency-probe`, `/tmp/hc-validate.*`) and `~/.hermes/backups/mnemosyne-fix-20261020/`; `/improve-memory` to shrink `MEMORY.md`.

**Session 134 next steps:**
1. Walk the post-reboot checklist (memory `project_post_reboot_pickup_20261019`): confirm gaming's new generation, Proton Bridge login + keyring entry, `himalaya envelope list`, Hermes checker logging a real verdict.
2. User-only: revoke the Gmail app password.
3. Carry-overs from session 132: Hermes checks 6–8, Mod+G visual check, `/fleet-rollout` for laptop + natalie-laptop (+ vpn-server when online).

**Session 132 next steps:**
1. Hermes: run plan checks 6–8 (tool calls, ~50K-token session, `llm-off` frees VRAM).
2. gaming: press Mod+G once and confirm neither monitor jumps (still unproven from session 131).
3. Carry-overs: `/fleet-rollout` for laptop + natalie-laptop + vpn-server; the DMS 10-min idle-lock check; Natty moving the two `.jpg`s off `~/Shared`.

**Session 131 next steps:**
1. gaming: press Mod+G once and confirm neither monitor jumps (`c8062a6` is live, the behavior isn't proven).
2. ~~When ready: "start the Hermes plan" → settle its six decisions first.~~ **DONE session 132.**
3. Carry-overs: `/fleet-rollout` for laptop + natalie-laptop + vpn-server; the DMS 10-min idle-lock check; Natty moving the two `.jpg`s off `~/Shared`.

**Session 130 next steps:**
1. Nothing owed for the share fix. Have Natty confirm she can move the two `.jpg`s off `~/Shared` on natalie-laptop.
2. Carry-overs from session 129: `/fleet-rollout` for laptop + natalie-laptop + vpn-server; the DMS 10-min idle-lock check. (gaming's `79607cc` rebuild is DONE — it rode along with this session's switch.)

**Session 129 next steps:**
1. **gaming: `rebuild-switch`** to bring `79607cc`'s global-skill fixes live; check the two new `lib/`/`land-prs` script paths exist.
2. Let gaming idle 10 min once to confirm the DMS lock fires and quickshell survives (`13e4616` is live, the behavior isn't proven).
3. Pick from the six audit follow-ups in Known Issues — `classify-shared-file.sh` is the one that silently skips checks; the rest are low-risk.
4. `/fleet-rollout` for laptop (when online) + natalie-laptop + vpn-server — unchanged, now also carries `27eb91f`/`79607cc`.

**Session 128 next steps:**
1. **gaming: `rebuild-switch` for `13e4616`**, then verify DMS shows a 10-min auto-lock and swayidle is gone; leave it idle once to confirm it locks (and quickshell survives).
2. **`/fleet-rollout` for laptop** (when online) + natalie-laptop + vpn-server — now also carries session 128's commits.
3. First real `land-prs` run is still its end-to-end test (live on gaming now). Check whether blueprint-smith's fork-PR approval was tightened to `all_external_contributors` (left with that session).

**Session 127 next steps:**
1. **Rebuild gaming** (`nh os switch` or `boot`+reboot) to bring `land-prs` + `brief-reviewer` live; check `ls ~/.claude/skills/land-prs ~/.claude/agents/brief-reviewer.md` and that `subagent_type: "brief-reviewer"` resolves in a new session.
2. **`/fleet-rollout` for laptop** (when online) + vpn-server — unchanged from session 126; carries `2d3ddb5` too.
3. On natalie-laptop, confirm the SSH login is WARN-free after the share idles 5+ min; then revoke the pre-rotation Tailscale OAuth client.

**Session 126 next steps:**
1. **`/fleet-rollout` for laptop** (when it's online) + vpn-server — the only hosts still behind; laptop also needs `git pull` for `7304ad5`/`8aca584` (no rebuild needed for those).
2. On natalie-laptop, confirm the SSH login is WARN-free after the share idles 5+ min.
3. Then revoke the pre-rotation Tailscale OAuth client. Sidekick Phase B unchanged.

**Session 125 next steps:**
1. **`/fleet-rollout`** to bring `8af18b1` + `1903228` (and the 10-09 bump on non-gaming hosts) live; on natalie-laptop, check the SSH login is WARN-free after the share idles out.
2. Session 124's reboot item is DONE (gen 430 booted, zsh fix + `slice-builder` confirmed). Session 123's Sidekick Phase B is unchanged.

**Session 124 next steps:**
1. **gaming: reboot onto gen 430** (already staged via `nh os boot`) — activates `slice-builder` and the zsh fix in new Claude sessions. Check: `echo =====` works in a fresh Claude session; `subagent_type: "slice-builder"` resolves.
2. Launch Sidekick sessions from `~/projects/Sidekick`, not the old ADHD-Assistant path (project skills are invisible otherwise).
3. Session 123's Phase B + earlier rebuild backlog unchanged.

**Session 123 next steps:**
1. **Sidekick Phase B** when ready: add `sidekick` flake input + `hosts/gaming/sidekick.nix` + `sidekick-env` sops secret (VAPID keys need the app's `gen-vapid`, milestone M2) + CI deploy key. Then remove the temporary `--operator=bosko` line.
2. Rebuild backlog from earlier sessions is unchanged.

**Session 120 next steps:**
1. **User: rebuild gaming** (picks up the bump + 0.8.3 / no pin), restart niri or reboot, then open Steam File/Store/Library dropdowns. Report back; if fixed, move the xwayland-satellite registry row to PAST and update `project_steam_dropdown_menu_bug`. If regressed, `git revert 7881fcb`.
2. This bump stacks onto the unapplied fleet-rollout backlog (laptop/natalie-laptop still owe rebuilds).

**Session 119 next steps** (see Current Goals):
1. **User: take the pi-hole Teleporter backup** (`sudo pihole-FTL --teleporter` on the Pi, scp to a non-repo path on gaming) and copy famdash's `db.json` + `db.json.bak`.
2. **Start the famdash host** (`new-host` skill; FamDash as SSH flake input + `buildNpmPackage`, `FAMDASH_DB` patch, sops Wi-Fi PSK captured by the user in a separate terminal).
3. Earlier fleet-rollout backlog (session 118) is unchanged.

**Session 118 next steps** (see Current Goals for full detail):
1. **All hosts: `/fleet-rollout`** to apply PR #29's flake bump (nixpkgs/home-manager/dms/sops-nix) — stacks with the existing multi-bump, printer, and skill rebuild backlog.
2. No other action pending from this session — PR #29 is merged, local `main` is synced.

**Session 117 next steps** (see Current Goals for full detail):
1. No repo/host action pending from this session — all work landed in the Claude memory/skill layer or was already merged (PR #28). The laptop/natalie-laptop rebuild backlog carries over unchanged from session 116.
2. Optional, low-priority: extend `rotate-project-state.sh` to also rotate Recent Decisions/Known Issues (see Known Issues) if either keeps growing.

**Session 116 next steps** (see Current Goals for full detail):
1. **laptop + natalie-laptop: `git pull`, then `nh os switch`** to bring the static Canon printer queue (`8085a0e`) live — laptop can't print at all until then; natalie-laptop can print in the meantime via the live-applied queue.
2. No other action pending — the `xwayland-satellite` pin re-check found no change, and the model-guidance question was purely informational.

**Session 115 next steps** (see Current Goals for full detail):
1. **gaming: rebuild+reboot** to bring PR #26's global skill fixes live in `~/.claude` — can ride along with the existing rebuild backlog (laptop/natalie-laptop pull+rebuild, etc.).
2. No other action pending from this session — the F1 governance question is resolved and recorded in memory; the dream overview snapshot's stale `Status:` line is deliberately left as-is (see Recent Decisions).

**Session 114 next steps** (see Current Goals for full detail):
1. **laptop + natalie-laptop: `git pull`, then rebuild (`boot` recommended)** via `/fleet-rollout` — one rebuild lands the 09-07 and 09-20 flake bumps, the reorganization, the `desktop.yaml` split and the skill backlog; then check `/mcp` connects the tailscale server on each.
2. **Revoke the pre-rotation Tailscale OAuth client** once both have rebuilt.
3. **Finish the redaction** of `~/.claude/history.jsonl` and the exposing session's log, delete `~/.claude/redaction-backup-20260921`, and decide whether to rotate the `bosko`/`natty` login hashes.
4. Small follow-ups: `references/` boundary in `review-improve-system-pr`'s script; watch the first CI run of `lib.moduleSmoke`; OpenSubtitles still waits on the user's opensubtitles.com credentials.

**Session 113 next steps** (see Current Goals for full detail):
1. **All 3 desktop hosts: rebuild (`boot` recommended)** to pick up the 2026-09-20 flake bump — `/fleet-rollout` applies it together with the older 2026-09-07 bump and the skill-ecosystem backlog.
2. Nothing pending on the pi-hole list change (live, 29 lists, gravity rebuilt) or the xwayland-satellite pin (keep; re-run `pinned-package-status-check` when #156 shows activity or a release newer than 0.8.2 appears).

**Session 112 next steps** (see Current Goals for full detail):
1. **Install OpenSubtitles once the user has opensubtitles.com credentials** — everything else from the Jellyfin plugin research is done (Intro Skipper + YouTube-metadata live).
2. No rebuild/reboot needed for anything from this session — the only repo change (`jellyfin-api-key` secret + `add-secret` skill fix, `fcae72c`) isn't wired into any NixOS module and the `add-secret` fix is project-local (already live).

**Session 111 next steps** (see Current Goals for full detail):
1. **All 3 desktop hosts: rebuild+reboot** to bring the skill-ecosystem work live in `~/.claude`, including the new `skill-builder` agent (needs the reboot to be dispatchable by name) — can ride along with the existing backlog.
2. No code/config changes otherwise — pure Claude-ecosystem process work across 4 commits (creative-example audit, `references/`-routing refactor + Nix-wiring-gap fix, closing that gap for future skills, a twice-run `/improve-system` sweep).

**Session 110 next steps** (see Current Goals for full detail):
1. **Any host: rebuild (no reboot needed)** to bring the absolutist-rules rewrite live in `~/.claude` — can ride along with the existing backlog.
2. No code/config changes otherwise — pure skills/CLAUDE.md wording audit. xwayland-satellite pin re-confirmed holding (no dropdown-bug recurrence since the 09-09 switch); no action needed until upstream #156 closes.

**Session 109 next steps** (see Current Goals for full detail):
1. **All 3 desktop hosts: rebuild+reboot** to bring `improve-system`'s new report-file-verification gotcha live in `~/.claude` — can ride along with the existing rebuild backlog.
2. No config/host changes otherwise — pure skills/process session (PR #23 review+merge, a send-results root-cause, a combined skill-suggestion/skill-upgrade pass).

**Session 108 next steps** (see Current Goals for full detail):
1. No new host action added — the `printing.nix` move rides along with the existing rebuild backlog (system-config-printer, the 2026-09-07 flake bump, PR #20/#21 skill fixes, the xwayland-satellite pin).
2. If the "no internet connection" symptom recurs, diagnose it fresh (see Known Issues) — nothing was actually investigated the one time it was raised.

**Session 107 next steps** (see Current Goals for full detail):
1. **natalie-laptop: rebuild (boot)** to drop the VirtualBox host module — no functional loss expected, it was still pending its first-ever build.

**Session 106 next steps** (see Current Goals for full detail):
1. **All 3 desktop hosts: rebuild (switch)** to pick up `system-config-printer`, then launch it and confirm it shows the print queue.

**Session 105 next steps** (see Current Goals for full detail):
1. ~~**gaming: rebuild (switch)** to apply the Mod+G Deezer stagger fix AND the xwayland-satellite 0.8.1 pin, then relaunch Steam to test whether the dropdown menus behave. Revert (`git revert 4201283`) if not.~~ **Done (see session 110/113):** gaming gen 414 has both; dropdown bug user-confirmed fixed 2026-09-15.
2. No action pending on the kitty change — it was reverted before ever being applied to any host.
3. No action pending on Secure Boot — informational answer only; revisit once the specific game's anti-cheat requirement is confirmed.

**Session 104 next steps** (see Current Goals for full detail):
1. **All 3 desktop hosts: rebuild** to pick up the 2026-09-07 flake bump (PR #21) and PR #20's skill fixes — can ride along with every other pending switch below.
2. No repo changes this session otherwise — pure review/merge + one interrupted, unfixed investigation (btop GPU panel).

**Session 103 next steps** (see Current Goals for full detail):
1. **gaming: rebuild (switch)** to apply the kitty full-screen fix, then `/wayland-screenshot kitty` to confirm it opens full screen rather than half.

**Session 102 next steps** (see Current Goals for full detail):
1. **gaming: rebuild (switch)** to apply the Mod+G Deezer stagger fix, then confirm Deezer opens alongside the other 4 apps on a real Mod+G press.
2. Steam dropdown-menu bug — no fix pending, check back on `xwayland-satellite#156` manually next time it's touched.

**Session 101 next steps** (see Current Goals for full detail):
1. **All 3 desktop hosts: rebuild+reboot** to bring PR #18's repo-managed skill fixes live in `~/.claude` (can ride along with every other pending switch).
2. No code/config work pending from this session otherwise — it was a skills/process close-out only.

**Session 100 next steps** (see Current Goals for full detail):
1. **gaming: reboot** to activate the staged hplip drop + flatpak ordering fix.
2. **gaming: one more `nh os boot`** (before or after that reboot) to pick up `improve-system`'s new Discord Step 5, since it was committed after the currently-staged generation.
3. **laptop/natalie-laptop: rebuild+reboot** — still carry the entire session-92-through-99 backlog that only gaming has picked up so far.

~~0000000a. Run `nh os boot` + reboot on gaming to bring the 2026-08-09 skill-audit fixes + flake bump + VPN watchdog timer live~~ (session 70) — **RESOLVED (session 71)**, see Known Issues.
~~000000. Run `nh os switch` to bring the 2026-07-30 skill-audit fixes live~~ (session 66) — **RESOLVED (session 67)**, see Known Issues; gaming's 2026-08-03 reboot+switch activated these.
~~0000000. laptop: `nh os switch` to pick up the docx/odt mimetype fix and the CIFS bare-hostname fix~~ (session 66, `7bedfb3`/`baad313`) — **RESOLVED (session 71)**: laptop fully rebuilt/rebooted multiple times this session, long after these commits.

> **Stale-content note (session 50):** most numbered items below overlap with, and are superseded by, the "Current Goals → Short-term" section above, which is kept current each close. This list spans sessions 27-45 and hasn't had a dedicated pruning pass; items are left as historical record rather than re-verified one by one (no first-hand ground truth for the oldest ones). Item 000 below was corrected this session because it was actively, verifiably wrong (referenced a Plasma switch that session 50 reversed) — treat any other item describing a host's DE/config state as suspect until cross-checked against "Current Goals" or "Known Issues" above.

00000. **All 3 desktop hosts: rebuild + reboot to activate the `/srv/shared` Samba share (session 63)** — `rebuild` on **gaming first** (it's the server; laptop/natalie-laptop's CIFS mounts have nothing to reach until it's up), then laptop and natalie-laptop (user's own call, sudo-gated). After gaming reboots, confirm `smbstatus`/`systemctl status samba-smbd` is active and `/srv/shared` exists locally. After each client reboots, confirm `~/Shared` appears as a symlink in Thunar for both `bosko` and `natty`, that opening it triggers the CIFS automount (`systemctl status srv-shared.automount`), and that both users can read/write files under it from either machine.
0000. **gaming + laptop: rebuild + reboot to pick up sessions 43-45's niri keybinds/window rules, the kdeglobals fix, the flake bumps, and session 45's `open-maximized` rules** — after boot, verify Mod+G launches the full 7-app setup (kitty/steam/lutris/vesktop/zen/deezer/qbittorrent), Mod+E opens dolphin, gaming's per-monitor window rules spread all 7 apps correctly across the two outputs (asus-1/2/3 = kitty/steam/lutris, dell-1/2/3/4 = vesktop/zen/deezer/qbittorrent), dolphin renders dark-themed without needing an interactive switch first, and Kitty/Vesktop/Zen Browser/Deezer/qBittorrent all launch already-maximized (session 45). qBittorrent's autostart-vs-Mod+G race fix is separate and already live — no reboot needed for that part. Can ride along with the other pending lock-bump reboots below.
000. **natalie-laptop: rebuild + reboot to activate the natty DMS fix (session 42, `4dd1759`/`aa8b0c9`) and session 50's Plasma removal** — user is doing this themselves. After boot: pick niri from SDDM as `natty` and confirm DMS actually starts (previously totally absent for that user); pick niri as `bosko` and confirm no regression. **Corrected (session 50):** the original version of this item said to also test a Plasma login — no longer applicable, `plasma.nix` was removed from this host's flake entry (niri-only now). This closes the loop on a bug reported live in session 42.
00. ~~Rebuild + reboot + start a new Claude Code session to pick up session 38's skill fixes~~ — **DONE (session 39):** rebuilt; confirmed live without needing a new session. Still worth spot-checking that `interview` reads its `assets/brief-template.md`, `ask-team` resolves the shared knowledge-base path, and `search-pkg`'s offline fallback actually returns results, next time one of those is used for real.
0a. **gaming + laptop: rebuild + reboot to activate the Niri `config.kdl` Home Manager symlink AND the new `qt6ct.conf` (session 34 `b9913b5`..`bf2ba35`, session 35 `b3bbb47`)** — can ride along with the other pending lock-bump reboots below. After boot, verify `Mod+Return` opens kitty, `Mod+B` opens the browser, gaps render at 8px, DMS's settings UI can still write its own theme/layout files, and qBittorrent (or any Qt app) is dark-themed after a restart. On laptop specifically, since it's a fresh activation there, also confirm DMS's `qtThemingEnabled` is `true` in `~/.config/DankMaterialShell/settings.json` — flip it and run `dms ipc call theme light && dms ipc call theme dark` if not.
0. **All hosts: activate the accumulated lock bumps** (`48c11d3` + waiver `aa3d690` from session 29, stacked with session 31's and now session 32's further nixpkgs/home-manager/dms/financeguru bumps) — first rebuild per host pulls linux-zen 7.1.2 + several weeks of unstable (large download; zen kernel change ⇒ reboot required on desktops). `/fleet-rollout` is the structured path, or ride it along with the per-host rebuilds below. **At the next nixpkgs bump, test removing the pnpm-10.29.2 waiver** from `nix.nix` (see Known Issues).
0b. **gaming: rebuild + reboot to activate the Niri DE switch (session 33, `34a7dbe`)** — this rides along with item 0's stacked lock bumps, so it's one reboot either way. After boot, test the actual gaming use case: Steam/Proton launch under Niri, controller input, cursor rendering (the `GBM_BACKEND`/`__GLX_VENDOR_LIBRARY_NAME`/`LIBVA_DRIVER_NAME` vars just added should prevent software-render fallback), and gamescope. If broken, the previous Plasma generation is still selectable at the boot menu — no dual-DE fallback exists by design.
1. **Rebuild gaming to surface pending global skill changes**, now also including the session-29 gotchas to the repo-managed `interview` and `skill-audit` skills, including the session-28 `/improve-system` skill-audit fixes (hardened `enumerate-skills.sh`, the co-author-line fix in `git-commit`/`session-closer`/`repo-creator`, the `git-commit`/`git-push` behavioral-drift fix, the `new-skill` AskUserQuestion fix, and the team-member-family path cross-references), the new `research` skill (session 27), and the session-18/20/21/23 skill edits — `nh os boot /home/bosko/NixOS` + reboot makes the `dotfiles/`-based skill edits live in `~/.claude/skills/`. The same gaming rebuild also drops the `brobot` packages (`yt-dlp` + closure, −187 MiB). All project-local `.claude/skills/` changes (including all of session 28's `nixos-gc`/`ssh-host`/`switch-de`/`new-peer`/`bump-input`/`pin-input`/`new-host`/`audit-config`/`save-memory` fixes) are already live. (Can ride along with the MTU/VPN rebuild below.)
2. **Rebuild desktop clients to apply `wg0 mtu = 1380`** — `rebuild` on laptop (user is doing this next), gaming, and natalie-laptop to make the MTU clamp (`eb69c43`) permanent; laptop is currently back at 1420 after the wg toggle. Use `vpn-on`/`systemctl restart wg-quick-wg0` if a tunnel goes stale.
3. **gaming: rebuild + reboot** — applies the `::/0` drop (`2f67083`) and the session-10 IPv6 disable. Afterward confirm `systemctl status wg-quick-wg0` is **active** and the WireGuard handshake is live (`/vpn-status`), then re-check Jellyfin artwork.
4. **Apply rebuild + reboot (or `nh os switch`) on laptop**: activate managed Claude Code policy, package consolidation, the OnlyOffice font fix (session 28), and other pending changes. Remove old hand-maintained `~/.ssh/config` afterward.
5. **Apply rebuild + reboot (or `nh os switch`) on natalie-laptop**: activate managed Claude Code policy, FinanceGuru package, the OnlyOffice font fix (session 28), session 50's Plasma removal (niri-only now), and other pending changes. Remove old `~/.ssh/config` afterward.
6. **Interface-scope Avahi mDNS firewall**: edit `modules/printing.nix` to replace `services.avahi.openFirewall = true` with interface-scoped rules restricting UDP 5353 to the LAN interface only.
7. **AMD card swap on gaming**: when the physical card arrives, remove `nvidia.nix` from gaming's module list in `flake.nix`; run `rebuild` in terminal and reboot; verify `amd.nix` is sufficient on its own.
8. **Re-add `server` host when hardware arrives**: use `/new-host` skill to scaffold; pin to `nixpkgs-stable` (`nixos-25.05`) using the established pattern from vpn-server.
9. ~~Optional, router UI (not repo): add DHCP reservations for the desktop hosts~~ (session 30) — **moot for `ssh.nix`/`hosts.json` specifically (session 87)**: those now key off Tailscale IPs, not LAN DHCP addresses, so lease-table churn can no longer invalidate them. A router-side reservation could still be worth doing for other reasons (e.g. LAN-local troubleshooting), but it's no longer solving a live bug.
10. **Optional: wire `omarchy.nix` into a host to actually see it** (session 41) — it's never been booted live, only `lib.deSmoke`-verified. If ever prioritized, use `switch-de` on laptop, then visually verify with `wayland-screenshot` — the theme-switching pipeline, mako notifications, and new keybinds have only been checked for eval correctness, not runtime behavior.
