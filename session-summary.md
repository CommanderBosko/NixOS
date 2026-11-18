# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

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

## Session: 2026-11-13 (session 153) — natalie-laptop clock loop, chrony fix, `gh` login

**Focus**: Bring natalie-laptop back after a remote reboot, stop it happening again, and get its Claude session able to open PRs.

### What changed (and why)
- **natalie-laptop boot loop (#123):** after the reboot its RTC gave 2021-12-31, so Tailscale could not validate TLS, MagicDNS could not reach pi-hole, and chrony could not resolve the pool names; nothing could fix the clock. The user set it by hand in a real terminal (the `!` prefix gave `ssh -t` no TTY). The fix adds two Cloudflare anycast NTP IPs to chrony in the shared `modules/desktop-networking.nix`, so a years-wrong clock finds a source without DNS. Deep-eval passed 3/3; it was not built or booted.
- **natalie-laptop `gh` (#125):** the first device-flow code expired unentered; the second conversation finished the login. The token is plain text in `~/.config/gh/hosts.yml` because the SSH session had no keyring. Docs-only PR, merged after CI.
- **Landed from other sessions (summarised from commits, not narrated):** #119/#120 passwordless read-only `smartctl` for wheel, #121 and #124 an 80% charge cap on laptop and natalie-laptop, #122 the `host-health-scan` skill plus a wider `boot-error-triage` noise filter.

### Decisions
- IP-literal NTP in the shared module, not a DNS or RTC change; the missing resolver fallback and the BIOS clock were left alone.
- The clock reset was handed to the user in a separate terminal, with no `sudo -S` workaround.
- natalie-laptop's plain-text `gh` token was accepted rather than chasing a keyring.

### Issues / surprises
- Not live on natalie-laptop: #123 (no `162.159.*` in `chronyc sources`) and #124 (charge threshold reads 100), so the next reboot there hits the clock loop again.
- gaming runs gen 500 and has no smartd; staged gen 501 has smartd and the smartctl sudo rule. `laptop` timed out over SSH at close.
- natalie-laptop's `/etc/resolv.conf` listed only Tailscale's resolver although `desktop-networking.nix` calls 1.1.1.1 a fallback; not investigated.

### Next session
- Reboot gaming into gen 501 and check smartd and the sudo rule; rebuild natalie-laptop (then confirm the chrony IPs and the 80% cap) and `laptop` (check it is up first); check natalie-laptop's BIOS clock; finish removing the wowaudit config and tokens from Hermes.

**Commits**: `a307ee5..3bfda88` (7 commits, PRs #119-#125)

Secret-scan: clean (tree + 2,076 commits, all 3 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-12 (session 152) — laptop `gh` login, smartd on all desktops

**Focus**: Get the laptop agent's smartd PR opened and landed, find out why its own PR step failed, and spread smartd to every desktop host.

### What changed (and why)
- **laptop `gh` logged in (imperative):** the laptop agent's branch push worked (SSH keys) but its PR step failed because `gh` there had no token. A device-flow login over SSH (the user entered the code) put the token in the laptop's gnome-keyring, as on gaming; `gh pr view 116` from the laptop confirmed it.
- **smartd (#116, #117):** #116 enabled `services.smartd` on the laptop so NVMe health warnings land in the journal without sudo. #117 moved the line into the shared `modules/desktop-apps.nix` so gaming and natalie-laptop get it too; deep-eval passed 3/3 and CI was green. Both landed with `land-prs`.

### Decisions
- smartd goes in the shared module, next to `smartmontools` (#114), not per host.
- The `gh` fix stays imperative; nothing in the flake manages it.

### Issues / surprises
- Nothing is live: gaming's staged gen 500 predates both PRs and the laptops are not rebuilt. `systemctl status smartd` is unchecked everywhere.
- natalie-laptop's `gh` login was not re-checked.

### Next session
- Reboot gaming into gen 500 then rebuild again for smartd; rebuild both laptops; check `smartd` on all three; check natalie-laptop's `gh`; remove the stale wowaudit config and tokens.

**Commits**: `48aa238..830816c` (4 commits, PRs #116-#117)

Secret-scan: clean (tree + 2,060 commits, all 3 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-12 (session 151) — btop GPU fix, smartmontools, wowaudit/wowup removal

**Focus**: Close out ten conversations: four small PRs (#111-#114), two pin checks, and a herdr look at natalie-laptop's session.

### What changed (and why)
- **btop shows the NVIDIA GPU (#113):** the first fix (`gpu0` in `btop.conf`) could not work. nixpkgs' btop lacks `/run/opengl-driver/lib` in its RUNPATH unless built with `cudaSupport`, so `libnvidia-ml.so` never loaded. An overlay in `modules/nvidia.nix` fixes it; the GPU line appeared in the CPU box after the switch.
- **`smartmontools` on all desktop hosts (#114):** written by natalie-laptop's session, which could not open the PR (`gh` not logged in); this host opened it.
- **wowaudit MCP dropped from Hermes (#111)** and **`wowup-cf` removed from gaming (#112):** the user no longer wants either (CurseForge replaces WowUp).
- **Pin checks 11-11 and 11-12:** keep the pin, nothing changed.

### Decisions
- Fix btop in the build, not in the unmanaged `btop.conf`.
- smartmontools goes in the shared `desktop-apps.nix`.
- wowaudit token files left on disk for the user to delete.

### Issues / surprises
- `~/.hermes/config.yaml` still has the `wowaudit:` block after the Nix removal and the gen 499 switch; cause not diagnosed.
- `laptop` was unreachable over SSH again; herdr's `SendMessage` does not cross machines (only `--machine` pane commands do).

### Next session
- Reboot gaming into gen 500; pull and rebuild both laptops; remove the stale wowaudit config and tokens; laptop checklist and natalie-laptop key test; Oracle cleanup; lift the pin when vendor-reset lands.

**Commits**: `abd2911..ca606f2` (4 PRs, #111-#114)

Secret-scan: clean (tree + 2,054 commits, all 3 `secrets/*.yaml` encrypted).

---

