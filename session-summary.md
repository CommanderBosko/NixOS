# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

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

## Session: 2026-11-09 (session 148) — herdr Q&A for the boss session

**Focus**: Answer what herdr is and whether this session can talk to it, then close. The only conversation in this close's scan; it changed no repo files.

### What changed (and why)
- **Nothing in the repo from this conversation.** PRs #96-#101 landed since the 11-03 close in other conversations whose transcripts were not scanned, so those are recorded from commit messages and live checks: herdr on every desktop host (#101), a Waydroid `ExecStop` so shutdown stops hanging (#96), `wowup-cf` on gaming (#97), the VirtualBox host re-added on natalie-laptop (#98), and the weekly `/improve-system` skill-doc sweep (#100).
- **herdr answered over its socket, read-only:** this session is pane `w2:p1` and the `herdr pane|agent` CLI works from inside it. The boss session then asked what herdr overlaps with: both list sessions, read output and send input, but herdr works per pane over its own socket while boss uses the `cc-socks` sockets and kitty remote control. Nothing was sent to any pane.
- **Live state:** gaming's current and booted system are both gen 492 (2026-11-09 08:36/08:37), which carries herdr 0.9.5, `wowup-cf` and the Waydroid fix. laptop and natalie-laptop still owe a rebuild.

### Decisions
- None made here. Recorded PR #101's: herdr stays a plain `systemPackages` entry with config and the Claude hook imperative, because upstream has no NixOS or Home Manager module and a Nix install must not self-update.

### Issues / surprises
- `home.activation.trimClaudeSettings` deletes the whole `.hooks` key from `~/.claude/settings.json` on every rebuild, which would remove herdr's `SessionStart` hook. Inferred from the script, not observed yet.
- The first `scan-session.sh transcript` call failed ("no transcript directory") because I passed the `~/.claude/projects/...` path; it takes the repo path (`/home/bosko/NixOS`).

### Next session
- Decide how herdr's hook survives `trimClaudeSettings`; `/fleet-rollout` laptop and natalie-laptop; Oracle cleanup; watch the next `send-results` run; finish Waydroid and confirm a clean shutdown.

**Commits**: `0661e4d..b5f09c4` (11 commits, none from this conversation)

Secret-scan: clean (tree + 2,028 commits, all 3 `secrets/*.yaml` encrypted).

---

## Session: 2026-11-03 (session 147) — send-results publishes a Claude Doc

**Focus**: Close the conversation that moved `/send-results` from HTML artifact pages to Claude Docs (PR #94). Its transcript was not in this close's scan, so this is written from the commit message, the memory notes and live checks on gaming.

### What changed (and why)
- **PR #94 (`4bd25b5`, merged `23a990b`):** `send-results` now creates the report as a Claude Doc through the Claude Docs connector and posts the doc link to Discord. The user's rule is that documents go in Claude Docs, not hand-written HTML pages, so `wrap-html.sh`, `wrapper-template.html` and the `artifact-design` step are deleted; `improve-system`'s caveat and the `why-artifact-not-file-link` note say Doc now.
- **Live-tested the same day:** doc created, Discord answered HTTP 204, the user confirmed.
- **This close:** gaming's current system is gen 487 (22:29, after #94) and its booted system is gen 485 with the same kernel, so the vpn-server retirement from session 146 is live there (`wg0` gone, `tailscaled` active). The docs had it as "not live"; fixed.

### Decisions
- No HTML fallback: if the Docs tools are missing or the create is refused, the skill reports and stops, because falling back would break the rule the change enforces.

### Issues / surprises
- The weekly cloud `/improve-system` routine and `/dream` also call `send-results`; whether their environment has the Docs connector is untested.
- Still on the user: revoke the OCI API key, terminate the instance or tenancy, delete `~/.oci` (`config` and `oci_api_key.pem` are still there).

### Next session
- Oracle cleanup; check Pinchflat without wg0; watch the next scheduled `send-results` call; finish Waydroid; `/fleet-rollout` laptop and natalie-laptop.

**Commits**: `8589ebe..23a990b` (PR #94, 1 commit)

Secret-scan: clean (tree + 2,016 commits, all 3 `secrets/*.yaml` encrypted).

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

