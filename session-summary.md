# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

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

## Session: 2026-11-09 (session 150) — wowaudit MCP, herdr Hermes status, natalie-laptop key, second rollout

**Focus**: Close out nine conversations: three small PRs (#107-#109), a pin check, a second `/fleet-rollout` in boot mode, and two Q&As.

### What changed (and why)
- **wowaudit MCP connects in Hermes (#107):** the startup line "did not connect: wowaudit" was an OAuth login nobody had run. The user ran `hermes mcp login wowaudit --flow browser` (the browser auto-open failed in the sandbox, so the URL was opened by hand). The login grants read scope, so `tools.include` keeps 21 of the 39 tools; the 18 write tools would be rejected anyway and cost context.
- **Hermes panes show working/idle/blocked in herdr (#108):** my first diagnosis (the plugin reports only the session id) was wrong. herdr detects state from the screen, and its upstream Hermes manifest misses this build's working UI, so panes always read idle. A Home Manager-delivered override adds two working rules; verified live (idle -> working -> idle) and against a real approval prompt.
- **natalie-laptop's SSH key authorized for bosko (#109):** re-applied the one line on a fresh branch because the old branch was 157 commits behind; both branches deleted.
- **Second `/fleet-rollout`, first full boot-mode run:** laptop gen 208 and natalie-laptop gen 112 rebooted green; gaming gen 497 was staged last and the user rebooted it straight away.
- **Pin check:** keep the nixpkgs pin (vendor-reset and pinchflat still block, mcp-nixos fixed). The user chose `pinchflat-ngx` over a waiver.
- Home Assistant Q&A (no use today without smart-home devices) and "any unmerged PRs?" (none).

### Decisions
- A local detection manifest, not a plugin, fixes the herdr status: `pane report-agent` is ignored for built-in kinds. Cost: upstream fixes are masked until the override is dropped.
- wowaudit is limited to read tools; `set_my_defaults` is left out because it writes.
- Pin lift goes through `pinchflat-ngx` after a fresh DB backup, in the same change as the vendor-reset fix.

### Issues / surprises
- Rebooting gaming right after `nh os boot` ended the fleet-rollout session before the staged-profile check and the report files, so no new `memory-`/`output-` file exists for this run. The match was confirmed at close (gen 497 = the dry-run path).
- `laptop` timed out over SSH at close; natalie-laptop (gen 112) and gaming are healthy.
- `trimClaudeSettings` still strips herdr's Claude hook, but that no longer affects icons.

### Next session
- Check `laptop` is up and run the laptop checklist; test the natalie-laptop key; try wowaudit in a fresh Hermes chat; Oracle cleanup; Waydroid; watch the next `send-results` run; lift the pin when vendor-reset lands.

**Commits**: `7c5b226..48c9a86` (7 commits, 3 PRs)

Secret-scan: clean (tree + 2,044 commits, all 3 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-09 (session 149) — fleet rollout, boot-mode skill, Hermes wowaudit + herdr plugin

**Focus**: Close out six conversations: a first `/fleet-rollout` pass over all three hosts, the skill rewrite it motivated, two Hermes config PRs, laptop herdr machines, and a Wispr Flow research note.

### What changed (and why)
- **`/fleet-rollout` ran on all three hosts** (Training Mode ON): gaming gen 494, laptop gen 207, natalie-laptop gen 111, all rebooted or switched with zero failed units. It cleared the laptops' long rebuild backlog, so about 40 "owes a rebuild" bullets in `project-state.md` were pruned as false.
- **Remote `dry-activate` is unusable** for `bosko` (polkit denies the `systemd-run` activation), so the remote gate became a local build plus `nix copy`; remote hand-offs need `--elevate sudo --ask-elevate-password`. PR #104 (`0a8ea8e`) folded both into the skill and made boot the default (switch opt-in), with a new Step 5b to reboot remotes and gaming last.
- **Hermes:** PR #103 registers the wowaudit OAuth MCP server (login still owed, no `~/.hermes/mcp-tokens/` yet); PR #105 enables the `herdr-agent-state` plugin, which is not live until gaming's next switch (gen 494 predates it).
- **herdr:** laptop and natalie-laptop were added as saved machines (`laptop`, `natalie-laptop`), both over Tailscale IPs, in herdr's own state. The user asked for the `laptop` label; I picked `natalie-laptop` myself.
- Wispr Flow research saved to memory: no Linux client; `handy`, `whisrs`, `voxtype` exist in nixpkgs, none tried.

### Decisions
- Boot is the fleet-rollout default because a switch hand-off got run as `boot` anyway, and rebooting gaming ends the Claude session, so gaming goes last.
- Hermes plugin enablement lives in Nix, installation stays imperative (`herdr integration install hermes`), the same split as PR #101.
- #104 and #105 were landed without `land-prs`'s order prompt because the user said to land both once green; both merged cleanly (`9c410b0`, `8086ff8`).

### Issues / surprises
- `trimClaudeSettings` did strip herdr's Claude hook: `~/.claude/settings.json` has no `hooks` key after gen 493/494, while `herdr integration status` still says `current` (it only checks the script file).
- laptop's `srv-shared.mount` failed right after boot (race against gaming's share) and cleared on its own.
- The first fleet-rollout sweep of laptop failed twice: the user ran `boot` instead of switch, then the mount race. Neither was a config fault.
- `hermes mcp list` prints "install out of sync (node: not installed or outdated)"; not diagnosed.
- The wowaudit-MCP and the #105 plugin conversations were not in this scan; they are recorded from commits and live checks.

### Next session
- `nh os switch` on gaming for #105, then `hermes mcp login wowaudit --flow browser`; fix the herdr hook strip; verify the laptops; Oracle cleanup; Waydroid; watch the next `send-results` run.

**Commits**: `8e6fe8e..8086ff8` (7 commits)

Secret-scan: clean (tree + 2,036 commits, all 3 `secrets/*.yaml` encrypted).

---

