# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

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

## Session: 2026-11-18 (session 155) — nix-ld audit: trim, add, drop mesa/zulu

**Focus**: Review the nix-ld library lists for redundancy and gaps (with a `/research` run), then apply, probe-test and land the result on gaming.

### What changed (and why)
- **#144:** gaming's list dropped `zlib` (a nixpkgs default), `udev` (default systemd has libudev.so.1) and `xwayland` (no `.so` in its lib/), and gained `libgbm`, `libxkbcommon`, `libxcb`, `libxscrnsaver`, `libxshmfence`, `cups`, `libnotify`, `libxxf86vm`, `openal`, `libGLU` and `icu`; a comment notes the list merges with the defaults.
- **#145:** `zulu` and `mesa` dropped after the user chose to test them. Rift has its own runtime so zulu was unused (and its `libjvm.so` sits in a subdirectory nix-ld ignores); a probe binary through nix-ld showed GL/EGL/Vulkan work without mesa (RTX 3070 enumerated), and adding mesa back changed nothing. Closure -352 MiB.
- Also merged since the last close but done in other conversations: #140 Code Mode opt-in, #141 nix-ld on every desktop host, #142 ethtool on gaming, #143 Hermes hook timeout 120 s.

### Decisions
- Ground truth came from `nix eval` of the locked nixpkgs, not the web: the module merges user libraries with 14 defaults, which contradicted one Discourse post. 9 of 10 research sources were readable, most thin.
- Laptops stay on the defaults until a real binary fails there; a shared tier belongs in `development.nix`, not a copy of gaming's list.
- #145 landed only after the user rebuilt from the branch and the probe passed (the branch was kept unmerged for that test).

### Issues / surprises
- A `nix eval` helper first read `glib`, `pango`, `libva` and a few others as empty because their default output is `bin`/`dev`; `lib.getLib` was needed. Not a real finding.
- A shared REPL variable (`d`) was shadowed once, so a memory edit failed and was redone with an explicit path.

### Next session
- Rebuild laptop and natalie-laptop (they lack #140-#145) and confirm nix-ld plus the native `claude` build there; play one Steam game on gaming; the session-154 checks (smartd, WoL, Pinchflat-NGX, natalie-laptop chrony) are still open.

**Commits**: `06d266c..552b108` (6 PRs, #140-#145; this session's own are #144 and #145)

Secret-scan: clean (tree + 2,118 commits, all 3 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-15 (session 154) — nixpkgs pin lifted, pinchflat-ngx, kernel pin dance, natalie-laptop Wi-Fi

**Focus**: Close out two days of gaming and natalie-laptop work (17 conversations): unpin nixpkgs, move Pinchflat to NGX, survive a zen kernel panic, and keep natalie-laptop's Wi-Fi alive.

### What changed (and why)
- **Pin lift (#127):** `nixpkgs` back on `nixos-unstable`; vendor-reset dropped (the passthrough VM is scrapped), Pinchflat moved to `pinchflat-ngx` after a stopped-service DB backup, `gtk2`/`qutebrowser` dropped, `llama-cpp-cuda` limited to sm_86 so the dry-run stopped compiling ten architectures.
- **Pinchflat-NGX:** live; 16 migrated sources were typed `playlist` and failed metadata decoding. A URL round-trip fixed the live DB; upstream fixed it in `dev` (#216, PR #218), tested on a backup copy in a sandbox.
- **Kernel:** zen 7.3.4 panicked gaming's initrd twice, so #128 pinned 7.2.10 via a second input; nixpkgs then shipped 7.3.4-zen2 with the fix, #136 lifted the pin and gaming booted clean.
- **natalie-laptop (#137, #138):** AX201 firmware asserts on zen 7.3.4-zen2 and stable 6.18; only zen 7.2.10 works, so that host alone is pinned (gen 121). Root cause unknown. `/fleet-rollout` now hands off `cleanup-host` per green remote host, never gaming.
- **Small:** `shutdown-host` (#132), Wake-on-LAN for gaming (#135), mnemosyne version fix (#133), rtk override lifted (#130), flake bumps #129/#134.

### Decisions
- Host-only kernel pin for natalie-laptop rather than holding its whole nixpkgs: only 7.2.10 boots; 6.18 failed too.
- Unpin kept out of the flake bump and merged without a boot test: the reboot is the test.
- No `workflow` scope on the `gh` token; SSH pushes the upstream hermes-agent PR instead.

### Issues / surprises
- Two untested fixes each cost an offline reboot on natalie-laptop (now a feedback memory); the clock and Tailscale failures were only symptoms of no Wi-Fi.
- The dry-run script says `switch` for kernel jumps: use `boot`.
- Unchecked: WoL (`ethtool`, BIOS), `chronyc sources` and the 80% cap on natalie-laptop, laptop gen 217 details, `lsfg-vk`.

### Next session
- Verify gaming (smartd, WoL, BIOS), re-check Pinchflat-NGX for a real download on or after 2026-11-17, check natalie-laptop's chrony/cap/BIOS clock, rebuild laptop, settle merge vs squash in the weekly-PR skill.

**Commits**: `2a7fbbf..67fc63f` (26 commits, PRs #127-#138)

Secret-scan: clean (tree + 2,104 commits, all 3 `secrets/*.yaml` encrypted).

---

