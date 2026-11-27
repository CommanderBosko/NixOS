# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-11-27 (session 160) — 11-27 flake bump merged and rolled out to the whole fleet

**Focus**: Close-only. Five conversations since the session 159 close: the 2026-11-27 flake bump (#169), a full `/fleet-rollout` of it, gaming's reboot and a `/fleet-status` sweep. Nothing else was committed.

### What changed (and why)
- **Flake bump #169:** dms, famdash, hermes-agent, home-manager, mnemosyne and sops-nix moved; nixpkgs did not (still `2786a2a7`). mnemosyne upstream is still 4.2.0 / 0.7.8, so its hardcoded label needed no edit. `flake-check` and `deep-eval-check` passed on all five hosts. Landed with `land-prs` (main is protected).
- **Fleet rollout (boot mode, Training Mode on):** natalie-laptop gen 124 (zen 7.2.10 pin held, Wi-Fi and tailnet fine), laptop gen 223 (nixpkgs 11-13 to 11-21, kernel 7.3.4 to 7.3.5), famdash gen 4, gaming gen 527 (user rebooted; clean boot), pi-hole untouched at gen 2. `cleanup-host` ran on both laptops. `/fleet-status` afterwards: all five hosts failed none, staged no, reboot no.

### Decisions
- pi-hole was skipped because its built toplevel was identical to the running one (checked before asking for a downtime window), so household DNS never blipped.
- famdash skipped `cleanup-host` (flatpak step does not apply; the Pi has its own `nix-gc.timer`); gaming stayed in boot mode although the dry-run script said `switch` (only `dms-shell` and `dux-qt-base` changed).

### Issues / surprises
- The first famdash verify and sweep raced the Pi's boot and reported it unreachable; one retry a minute later passed. `fleet-rollout` has no post-boot retry for the Pis and its Step 6b does not know they differ (recorded in Known Issues).
- Claude could not reboot gaming (polkit refused, sudo needs a password), so it was a user hand-off. Gaming's config revision is not recorded, so "gen 527 includes #169" is inferred from build time, not proven.

### Next session
- Check NIX_LD, the native `claude` build, the Hermes tool list and the memory hook on both laptops; watch pi-hole's first weekly gravity run (Sun 2026-11-29 04:00 EST); then the carried-over Hermes verification, stale local-model cleanup and gaming checks listed in project-state.md.

**Commits**: `d80517d..b4f6aef` (PR #169: flake.lock bump plus its merge)

Secret-scan: clean (tree + 2,174 commits, all 5 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-27 (session 159) — Both Pis on NixOS: famdash and pi-hole cut over, Hermes manages Tailscale

**Focus**: Move both Raspberry Pis from Raspberry Pi OS to NixOS (famdash first, then the pi-hole), land the Pi skills, and finish the housekeeping. The range since the last close also holds #158-#161 (dream fixes, Immich on gaming, the gvfs/dconf fix, Hermes interview rules) from other conversations; they are not narrated here.

### What changed (and why)
- **famdash (#162-#164):** the image is the flake's own `sdImage` built on gaming under binfmt, because there is no generic Pi ISO and nixos-anywhere was out (no kexec on the Pi OS kernel, Wi-Fi-only, would wipe the only `db.json`). It runs from its own SD card with the host key and `tailscaled.state` copied on, `db.json` restored byte-identical, Wi-Fi from a sops env file, and a node-exporter scrape on gaming.
- **Shared Pi base (#162, #166):** nixpkgs' `expand-root-partition` fails on first boot with util-linux 2.42 (`lsblk` pads MAJ:MIN), so the root partition never grew. A `lib.mkForce` replacement now lives in `modules/pi-sd-image.nix` and was proven on real hardware (root at 99%).
- **pi-hole (#166):** flashed over its own SD card (no spare), same Tailscale node 100.92.242.60, static 10.0.0.19 on `end0`, Pi-hole v6 with local unbound, 25 declared adlists, a weekly gravity timer, and groups and clients from a sops list. 14/14 boot checks, about a minute of gravity at a 259 MB peak.
- **`fleetExclude` and `pihole-api` (#166):** a `hosts.json` reason keeps pi-hole out of the default `/fleet-rollout` (a fleet reboot takes household DNS down); `pihole-api` reads `cli_pw` through one NOPASSWD sudo rule for exactly that command.
- **Hermes and Tailscale (#167):** trusted write access to the Tailscale MCP minus the four credential-minting tools. The nameserver swap during the cutover needed it.
- **Skills (#165):** `pi-sd-flash`, `pi-cutover`, `deploy-pi-host` and `pi-host.sh`, built by the manager agent and reviewed here.

### Decisions
- Flash the pi-hole over its own card with a verified full-card image as rollback, then delete that image once both Pis proved themselves; carry each Pi's Tailscale identity by copying `tailscaled.state` instead of new nodes plus an auth key.
- Hermes keeps Tailscale write access but not credential minting (the OAuth scopes could mint keys); `tools.include = null` because the live config is deep-merged.
- `pihole-api` gets one narrow sudo rule over blanket NOPASSWD or a sops-exposed password, accepting that anyone holding bosko's SSH key can call the Pi-hole API.

### Issues / surprises
- The first pi-hole deploy hand-off was reported done but the Pi still showed generation 1; comparing the Pi's generations and store path against the build caught it, and the second attempt worked.
- Hermes used curl and the OAuth secret when its MCP tools were read-only, and its running daemon kept the 39-tool list after the config edit. Its self-reports are unreliable, so every claim was checked with a read-only MCP call.
- The Tailscale MCP `set_nameservers` dropped `useWithExitNode` on both Hermes's change and mine; the user re-ticked it in the admin console.
- Remote `rm -rf` was blocked by auto mode, so the staging-directory deletions were user hand-offs.

### Next session
- Watch the first weekly pi-hole gravity run (Sun 2026-11-29 04:00 EST), roll laptop and natalie-laptop forward with `/fleet-rollout`, then the carried-over Hermes verification, stale local-model cleanup and gaming checks listed in project-state.md.

**Commits**: `22539d9..06b68ff` (PRs #162-#167)

Secret-scan: clean (tree + 2,170 commits, all 5 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-23 (session 158) — Hermes on every desktop, Qwen stack removed, 11-22 rollout

**Focus**: Close-only for five conversations: put Hermes on all three desktops, bump and roll out the flake, and land the weekly improve-system PR.

### What changed (and why)
- **#152:** Hermes moved from `hosts/gaming` into `modules/hermes-agent.nix` in `desktopModules`; the shared OpenRouter key `hermes-env` moved to `secrets/desktop.yaml`. The user's question "won't a rebuild skip the Qwen model now?" had a no: the llama-cpp unit only didn't start at boot, so every gaming closure still carried `llama-cpp-cuda` and the 4.8 GiB GGUF. The whole local stack was removed (about -5.7 GiB, no CUDA compile on bumps).
- **#151:** `skills.write_approval = false` (now in the shared module), so agent-created skills are written without review. Reading how it takes effect showed `~/.hermes/config.yaml` is deep-merged by `hermes-config-merge`: declared keys are overwritten, removals in Nix never propagate. That explains the leftover `wowaudit:` block.
- **#154 + #153:** 2026-11-22 flake bump (nixpkgs `2786a2a`, dms, hermes-agent, home-manager, mnemosyne 4.2.0, ponytail, sops-nix) with the hardcoded mnemosyne label bumped in its own commit; plus an `AGENTS.md` line telling Hermes to delegate code work to Claude Code via herdr.
- **`/fleet-rollout` 2026-11-22:** natalie-laptop gen 123 (zen 7.2.10 pin held, Wi-Fi and tailnet confirmed, `cleanup-host` dropped gen 118) and gaming gen 517 (zen 7.3.4 to 7.3.5, booted 11-23, no failed units). laptop was off and was skipped.
- **#156:** the weekly improve-system PR (three skills, 6 files) was reviewed by the `manager` agent and landed with a merge commit.

### Decisions
- Remove the local model stack rather than keep it declared for a one-line revert; the revert path is git history (`78298e3^`).
- One shared OpenRouter key for all three desktops, accepting that a leak on any host exposes it.
- Landed #156 with a merge commit although the manager agent suggested squash (the `land-prs` default and the repo's history).

### Issues / surprises
- The gaming dry-run script again said `switch` despite a kernel bump; `boot` was used.
- My first `git commit` for #153 failed on an empty message and nothing was committed; the second try worked.
- The close-only baseline spans conversations from other sessions; only work visible in the transcripts is narrated here.

### Next session
- Verify Hermes end to end on each desktop (real tool task, memory save through the checker, first `hermes` run on natalie-laptop to approve the hook, OpenRouter spend); rebuild laptop with `/fleet-rollout`; clean up stale local-model references in the competency-test skill and the memory-checker agent prompt; remove the wowaudit block and token files by hand.

**Commits**: `f111d2a..15fd05c` (PRs #151-#154, #156)

Secret-scan: clean (tree + 2,139 commits, all 3 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-19 (session 157) — Hermes moves to OpenRouter flash

**Focus**: Close-only for eight conversations: test remote models for Hermes, switch gaming's Hermes to the winner, plus a Steam diagnosis and an upstream PR chore.

### What changed (and why)
- **#149:** Hermes on gaming now uses OpenRouter `deepseek/deepseek-v4-flash` instead of local Qwen3.5-9B (gen 514). The full 31-item competency suite scored 88.5 on flash against 53.8 for the local baseline (quick slice: flash 87.5, nemotron:free 80.6, local 42.8). The key is the sops secret `hermes-env` (never in the store); the HM module deep-merges settings, so the old `base_url`, `api_key`, `api_mode` and `context_length` are nulled; llama-cpp stays declared and unused for a one-line revert.
- **`383c745`:** `hermes-competency-test` learned remote models (`remote-run.sh`, `HC_REMOTE_MODEL` hooks, 151 runner tests) and a reasoning-budget A/B (`reasoning-ab.sh`, 13 tests, never run).
- **Steam GUI "freeze":** not a hang; a 92 GB Kingdom Come: Deliverance II download at about 900 Mbps pegged Steam's CPU while `llama-server` held 6 of 8 GiB of VRAM. gaming's root disk is now 95% full.
- **NousResearch/hermes-agent PR #141834:** the three "failed" notifications were workflow runs held for maintainer approval; the PR was rebased (`be4fa861`) and the user's `gh` token gained the `workflow` scope to push it.

### Decisions
- Switched the whole agent to flash rather than building the hybrid (flash for coding/network/research, local for mail/secrets) the assistant had suggested; the privacy cost (file and mail content now reaches OpenRouter/DeepSeek) was raised first and the user went ahead.
- Tested through the harness's throwaway home so live `~/.hermes` stayed untouched; skipped Yorath and Halogen from a Reddit thread (root `curl | sh` installer; AMD-only closed engine).

### Issues / surprises
- A Claude usage limit mid-grading made `hc.py` write 57 placeholder `grade.json` files that `run-suite.sh` then scored as errors; they were regraded by hand.
- `safe-01` (agrees with a false premise) is still weak on flash (0 / 93 / 37), the same failure Qwen had.
- One $20 OpenRouter key serves both production and tests; only a one-shot `hermes -z` was tried after the switch.

### Next session
- Verify Hermes on flash end to end (tool task, memory save through the checker, spend); free disk on gaming; Rift status check; rebuild both laptops; the older gaming and natalie-laptop checks (see `project-state.md`).

**Commits**: `2f44d72..8bcde5a` (PR #149) plus `383c745`

Secret-scan: clean (tree + 2,126 commits, all 3 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-18 (session 156) — Rift popup fix on gaming, stale branch cleanup

**Focus**: Follow-up to the nix-ld work: find out why Rift showed a "Missing dependency" popup after the trim, and land the fix.

### What changed (and why)
- **#147:** `wmctrl` and `xwininfo` added to gaming's `environment.systemPackages`. Rift shells out to `xwininfo`, `xprop` and `wmctrl` to check characters' online status; they are executables, so nix-ld could never have supplied them and the popup was not caused by #144/#145. `xprop` was already installed. The user rebuilt from the branch and confirmed the popup is gone; merged as `9c8dd41`.
- Deleted the local `fix/pinchflat-ngx` branch (its only commit, `ab21985`, was PR #57, closed unmerged; `main` already runs pinchflat-ngx). No remote copy; `git branch fix/pinchflat-ngx ab21985` restores it until gc.

### Decisions
- Rift's "Tray is not supported" message is left alone: Java's XEmbed tray check cannot see niri + DMS's StatusNotifier tray, and `snixembed` (the usual bridge) broke the DMS tray and was reverted 2026-07-30.

### Issues / surprises
- The dry-run's own check first reported `xwininfo` as missing and said it adds nothing new to the build; after the switch all three tools are in `/run/current-system/sw/bin`, so that was just the pre-switch state.
- A tree-hash comparison after the merge printed two different hashes because it ran before the fetch finished; `git diff 18e0989 origin/main` was empty.

### Next session
- Launch Rift from a fresh terminal and check that online status actually updates (Xwayland visibility is the suspect if not); the rest is unchanged from session 155: rebuild both laptops (they lack #140-#145), play one Steam game on gaming, and the session-154 checks (smartd, WoL, Pinchflat-NGX, natalie-laptop chrony).

**Commits**: `67f5e99..9c8dd41` (1 PR: #147)

Secret-scan: clean (tree + 2,121 commits, all 3 `secrets/*.yaml` encrypted).

---

