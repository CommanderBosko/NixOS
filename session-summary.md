# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-06-17 (session 12) — promote nixos MCP server to user scope (reproducible)

**Focus**: Confirm the freshly-installed mcp-nixos server works post-reboot, then make it global and reproducible.

### What changed (and why)
- **Verified mcp-nixos is live** — after the reboot, a live `stats` call returned 134,973 packages, confirming the session-11 project-scoped server connects.
- **Promoted the server from project scope to user scope** (`f9a66e8`) so it's available in every project, not just this repo. `claude mcp add nixos mcp-nixos --scope user` writes the entry to `~/.claude.json`; the redundant project `.mcp.json` was `git rm`'d.
- **Made it reproducible** — added `home.activation.claudeMcpServers` to `dotfiles/bosko/bosko-claude.nix`: an idempotent jq reconcile of `.mcpServers.nixos` in `~/.claude.json` on every rebuild, mirroring the existing `claudeAllowList`/`claudeNixdPlugin` activation pattern. Repointed the `mcp-nixos` comment in `users.nix` at the new location.

### Decisions
- **Reconcile `~/.claude.json` with jq rather than symlink it read-only** — Claude Code rewrites that file constantly (auth, project history, toggles), so a `/nix/store` symlink would break it. The activation block touches only the single `.mcpServers.nixos` key, leaving everything else intact. Same trade-off already made for `settings.json` in this module.
- **User scope over project scope** — the value of live NixOS data isn't repo-specific; one global registration beats per-repo `.mcp.json` files.

### Issues / surprises
- None. Dry-run clean (1.80 KiB diff). The `enabledMcpjsonServers` entry in `.claude/settings.local.json` from session 11 is now a harmless no-op (it only gated the deleted `.mcp.json`).

### Next session
- It's global now via the `claude mcp add` write; a `rebuild` makes the activation block the source of truth (survives a `~/.claude.json` reset). No blocker.
- Standing backlog unchanged: laptop + natalie-laptop rebuild activations; interface-scope the Avahi mDNS firewall.

**Commits**: `f9a66e8` (1 commit)

---

## Session: 2026-06-17 (session 11) — wg-quick failure from leftover `::/0`; mcp-nixos server

**Focus**: A `rebuild` on gaming failed with `wg-quick-wg0.service` erroring out — diagnose and fix.

### What changed (and why)
- **Dropped `::/0` from the WireGuard peer's `allowedIPs` in `dotfiles/common/modules/vpn.nix`** (`2f67083`), leaving `[ "0.0.0.0/0" ]`. Session 10 disabled IPv6 but kept `::/0`; wg-quick installs a route per allowedIP, so `ip -6 route add ::/0 dev wg0` failed ("IPv6 is disabled on nexthop device") and wg-quick tore the interface down — the tunnel had been failing on every boot since session 10, not just warning. Added a `NOTE:` comment so `::/0` isn't re-added while IPv6 is off.
- **Added project-scoped mcp-nixos MCP server** (`720fe36`) — `pkgs.mcp-nixos` in bosko's packages + `.mcp.json` so Claude Code can query live NixOS package/option data; plus a routine `nix flake update` (`56983dd`). _(Both predate this conversation in the session-11 range.)_

### Decisions
- **The IPv6 disable and the `::/0` removal belong together** — this corrects session 10's recorded decision to keep `::/0`. With IPv6 off there's no stack to leak, so v4-only `0.0.0.0/0` is still a full tunnel. If IPv6 is ever restored on the server, flip `enableIPv6 = true` *and* re-add `::/0` as a pair, never one alone.

### Issues / surprises
- The rebuild "succeeded" (config activated) but reported the unit as failed — easy to misread as cosmetic. The journal's `ip link delete dev wg0` was the tell that the tunnel was actually down, not merely warning.

### Next session
- **gaming `rebuild` + reboot (user doing this next)** — then confirm `wg-quick-wg0` is *active* and the handshake is live (`/vpn-status`), and re-check Jellyfin artwork.
- Standing backlog unchanged: laptop + natalie-laptop rebuild activations; interface-scope the Avahi mDNS firewall.

**Commits**: `9c31511..2f67083` (3 commits: `56983dd`, `720fe36`, `2f67083`)

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

