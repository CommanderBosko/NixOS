# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-06-17 (session 10) — Jellyfin image black-hole → IPv6 disabled on VPN clients

**Focus**: Figure out why Jellyfin artwork/metadata wouldn't load on gaming, and fix it.

### What changed (and why)
- **`networking.enableIPv6 = false` added to the shared `dotfiles/common/modules/vpn.nix`** (`81cf1a2`). Jellyfin's TMDb provider was timing out (100s `HttpClient.Timeout` on `TMDbClient.GetConfigAsync()`) because TMDb resolves to IPv6-only addresses, but the full-tunnel WireGuard client routes `::/0` into a v4-only `wg0` (no IPv6 address; Oracle server doesn't route v6) — so all IPv6 black-holed. Disabling IPv6 forces IPv4 fallback through the tunnel. Applies to all three VPN clients (gaming, laptop, natalie-laptop).

### Decisions
- **Disable IPv6 rather than drop `::/0` from `allowedIPs`** — the disable fixes the black-hole while keeping the full-tunnel guarantee intact; dropping `::/0` would have leaked IPv6 traffic around the VPN (real IP exposed). Left `::/0` in `allowedIPs` so the config stays correct if the server ever gains IPv6.

### Issues / surprises
- Symptom presented as a Jellyfin/metadata-refresh problem but was a VPN routing issue. `curl -4` worked (<0.1s) while `curl -6` failed instantly — the tell that isolated it to IPv6.

### Next session
- **Run `rebuild` + reboot on gaming**, then re-run the Jellyfin metadata refresh (Replace all metadata + Replace existing images) to confirm artwork loads. laptop/natalie-laptop inherit the fix on their next rebuild.
- Standing backlog unchanged: laptop + natalie-laptop rebuild activations (managed Claude policy, Plasma switch, FinanceGuru, package consolidation); interface-scope the Avahi mDNS firewall.

**Commits**: `81cf1a2` (1 commit)

---

## Session: 2026-06-16 (session 9) — Sudo password masking (pwfeedback)

**Focus**: Make the sudo password prompt show a `*` per typed character so entered length is visible.

### What changed (and why)
- **Sudo pwfeedback enabled** (`dotfiles/common/modules/security.nix`): added `security.sudo.extraConfig = "Defaults pwfeedback";`. Since `security.nix` is in `commonModules`, the masking applies to every host. A comment records that CVE-2019-18634 (the old pwfeedback stack overflow) was fixed in sudo ≥ 1.8.31, so current sudo is unaffected.

### Decisions
- **Fleet-wide via commonModules, not per-host** — the behaviour is a global UX preference with no host-specific reason to differ.
- **Kept pwfeedback despite its CVE history** — the vulnerability is long-patched in the sudo version shipped; documented inline so a future audit doesn't re-flag it.

### Issues / surprises
- None. Dry-run regenerated `sudoers` cleanly (+10.4 KiB, no kernel/service changes).

### Verified
- User ran `switch` on gaming and confirmed the `*` masking works at the sudo prompt.

### Next session
- Standing backlog: laptop + natalie-laptop rebuild activations (managed Claude policy, Plasma switch, FinanceGuru, package consolidation); interface-scope the Avahi mDNS firewall. (gaming SDDM auto-login is already disabled and confirmed — not pending.)

**Commits**: `eeb03bc` (1 commit)

---

## Session: 2026-06-16 (session 8) — Jellyfin media server on gaming

**Focus**: Stand up a Jellyfin media server on the gaming host with hardware transcoding, get media reachable from every device, and capture the verification workflow as a skill.

### What changed (and why)
- **Jellyfin server on gaming** (`hosts/gaming/jellyfin-server.nix`, new): native `services.jellyfin` backed by the spare 1TB Samsung SSD reformatted ext4 and mounted at `/mnt/media` (pinned by UUID). NVENC hardware transcoding via the RTX 3070 (jellyfin user added to `render`/`video`). Firewall scoped to LAN (`enp4s0`) + WireGuard (`wg0`) only — no internet-facing ports. Shared `media` group + setgid Movies/Shows dirs so manual file drops stay readable by the scanner.
- **jellyfin-media-player client** for all desktop hosts (`dotfiles/common/modules/jellyfin-client.nix`, added to `desktopModules` in `flake.nix`).
- **qBittorrent: service → desktop GUI** (`refactor`): swapped the headless `qbittorrent-nox` service (localhost Web UI, finding H-6) for the `qbittorrent` desktop app, removing the listening Web UI to harden. Added `/mnt/media/downloads` (setgid `bosko:media`) as the save path so finished downloads stay readable by Jellyfin's scanner.
- **verify-service skill** (`.claude/skills/verify-service/`, new project-local): read-only post-rebuild health sweep for one systemd service on a host (unit active, listening ports, optional mount/data-dir ownership), distilled from the by-hand Jellyfin/qBittorrent verification done this session. Listed in CLAUDE.md.
- **flake update** (`1a207f3`): routine `flake.lock` bump.

### Decisions
- **NVENC over CPU transcoding** — RTX 3070 is already in the box; offloads transcoding for free.
- **Firewall scoped to LAN + wg0, never the internet** — media is reachable from the fleet (incl. remote over the VPN) without exposing Jellyfin publicly.
- **qBittorrent desktop GUI over the nox service** — eliminates the localhost-bound Web UI as an attack surface rather than hardening it.
- **Shared `media` group + setgid dirs** — manual drops and torrent downloads both stay group-readable by the Jellyfin scanner without per-file chmod.

### Issues / surprises
- None blocking. Verification was done by hand, which prompted distilling it into the `verify-service` skill so future service stand-ups are repeatable.

### Verified
- **Jellyfin confirmed working on all client devices (2026-06-16).** Server up on gaming with NVENC; playback confirmed across the fleet. Recorded as COMPLETE in memory — not a pending item.

### Next session
- Carryover (unchanged): rebuild+reboot laptop & natalie-laptop for the managed Claude policy, Plasma switch, FinanceGuru, package consolidation; interface-scope the Avahi mDNS firewall; reboot gaming to drop the fwupd ESP override and pick up the rebuilt skills (`claude-rules`, `verify-service`).

**Commits**: `1a207f3..ace485c` (4 commits)

---

## Session: 2026-06-15 (session 7) — claude-rules: add "Use Existing Skills First" rule

**Focus**: Decide whether the `claude-rules` skill should also enforce skill *usage*, then add the rule.

### What changed (and why)
- Added a fourth standing rule, **Use Existing Skills First**, to the `claude-rules` skill source (`dotfiles/bosko/claude/skills/claude-rules/SKILL.md`) and to this repo's `CLAUDE.md`. The rule: reach for an existing skill before doing a task by hand. Rationale — the existing three rules cover scope → verify → parallelize but say nothing about *consuming* the tooling already built, and this repo ships ~30 task-specific skills that are easy to reimplement by accident.
- Updated the skill's count (three → four), canonical ordering, and the Step-2 heading-match list so the new section is detected and inserted last.
- The CLAUDE.md variant names concrete repo skills and chains back to the existing "Skill Awareness" (create-a-skill) section — consume vs. author.

### Decisions
- Kept the new rule distinct from "Skill Awareness": that one is about *authoring* a skill when a pattern repeats; this one is about *using* one that already exists. They complement rather than duplicate.

### Issues / surprises
- None. The skill's `SKILL.md` change won't reach `~/.claude` until a rebuild (it's a `/nix/store` symlink); the `CLAUDE.md` change is live immediately.

### Next session
- Carryover (unchanged): rebuild+reboot laptop & natalie-laptop for the managed Claude policy, Plasma switch, FinanceGuru, package consolidation; interface-scope the Avahi mDNS firewall; reboot gaming to drop the fwupd ESP override (and to pick up the rebuilt claude-rules skill).

**Commits**: `411acfc` (1 commit)

---

## Session: 2026-06-15 (session 6) — ssh.nix famdash login fix

**Focus**: Correct an incorrect SSH host login in the shared ssh config.

### What changed (and why)
- Fixed the `famdash` host alias in `dotfiles/common/configs/ssh.nix`: `User = "natalie"` → `User = "natty"`. `natalie` is not a valid account on that box; `natty` is the correct login (matching the `natty` user used across the fleet).

### Issues / surprises
- None. One-line fix, self-contained.

### Next session
- Carryover (unchanged): rebuild+reboot laptop & natalie-laptop for the managed Claude policy, Plasma switch, FinanceGuru, package consolidation; interface-scope the Avahi mDNS firewall; reboot gaming to drop the fwupd ESP override.

**Commits**: `5a5b58e` (1 commit)

---

