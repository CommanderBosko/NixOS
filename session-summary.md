# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-08-19 — TCL TV and Fire Stick joined to the Tailnet

**Focus**: Get the TCL Google TV and Amazon Fire TV Stick onto the Tailscale mesh so Jellyfin's TV apps use a stable address instead of a drifting LAN IP.

### What changed (and why)
- No repo changes — entirely device-side. Installed Tailscale on the TCL TV via the Google Play Store (no sideload needed) and on the Fire Stick via sideloading (not in the Amazon Appstore search for this device). Pointed each Jellyfin app at gaming's tailscale IP (`100.66.15.1:8096`) manually instead of relying on LAN auto-discovery, which is broadcast-based and doesn't cross onto the tailnet.
- Ran `/interview` (lightweight path — a few blocking questions, not the full brief+review ceremony, since this was a well-scoped, quickly-diagnosable task) then `/research` (8 parallel `source-reviewer` agents, 6/8 usable sources) before giving install instructions, per standing CLAUDE.md rules.

### Decisions
- Lightweight interview path over the full ceremony — confirmed appropriate in hindsight, the task stayed a single bounded thread start to finish.
- Manual Jellyfin server entry (tailscale IP) over relying on auto-discovery for both devices.

### Issues / surprises
- Real gotcha: Tailscale's own marketing download page (`tailscale.com/download`)'s Android button links to the **Play Store listing**, not a raw APK — useless on Fire OS (no Google Play Services), and produced exactly the confusing symptom the user hit ("lists my other Android devices, wants a Google sign-in, no Fire Stick option"). Fixed by using **`pkgs.tailscale.com/stable/`** instead — Tailscale's own package mirror, serves the raw `.apk` directly, no sign-in.
- Confirmed the user's stick is a Fire TV Stick HD (1st gen) — a normal Fire-OS device, not the newer Vega-OS "4K Select" that blocks all sideloading outright.
- Walked through Jellyfin Quick Connect for password-free sign-in on both remote-control-only devices.

### Next session
- None — thread fully closed. Both devices confirmed connected on the tailnet and Jellyfin confirmed working by the user.

**Commits**: none (no repo changes this session)

---

## Session: 2026-08-19 — Pi-hole set up as a Tailscale global nameserver

**Focus**: Walk through configuring pi-hole as a DNS resolver on the Tailscale admin dashboard, then verify it actually works.

### What changed (and why)
- No repo changes — this was entirely a Tailscale admin-console configuration (`login.tailscale.com/admin/dns`), outside the flake. Added pi-hole (`100.92.242.60`) as a global nameserver: "Restrict to domain" left off (needs to resolve everything, not one domain), "Use with exit node" turned on (keeps pi-hole authoritative once a Tailscale exit node exists later), "Override local DNS" enabled fleet-wide.
- Tried to hand this off to browser automation (`claude-in-chrome`) first; user doesn't use Chrome, so walked them through the manual click-path instead.

### Decisions
- Kept this as a layer *on top of* session 82's flake-managed DNS override rather than replacing it — session 82 deliberately rejected this exact admin-console toggle as the primary mechanism (unreviewable, affects every device at once). What changed: the tailnet now has non-flake devices (pi-hole/famdash themselves, two phones) that the flake-managed override can never reach, so the admin-console setting fills that specific gap instead of being reconsidered as a replacement.

### Issues / surprises
- Discovered two new tailnet devices (`natalies-s23-ultra`, `pixel-6`) that joined sometime after session 82's close — not added this session, just noticed during verification. They have no flake-managed DNS fallback, unlike the 3 NixOS hosts.
- laptop and natalie-laptop were offline during this session, so the new nameserver setting could only be verified on gaming (`host doubleclick.net` → `0.0.0.0` via the system resolver, matching a direct query to pi-hole; `github.com` still resolves normally; pi-hole's own log shows the test queries landing).

### Next session
- Confirm the same DNS/ad-block check on laptop and natalie-laptop once they're online.

**Commits**: none (external dashboard config only)

---

## Session: 2026-08-19 — Jellyfin opened up on the Tailscale interface

**Focus**: Answer "does Jellyfin need adjusting for Tailscale?" by actually checking the firewall config, then fix and verify what was found.

### What changed (and why)
- Grepped the real config instead of guessing: `hosts/gaming/jellyfin-server.nix`'s `networking.firewall.interfaces` only opened port 8096 on `enp4s0` (LAN) and `wg0` (WireGuard) — `tailscale0` wasn't listed anywhere, and `services.tailscale.enable` doesn't auto-open ports on its own (confirmed against the real NixOS option list). Since `wg0`/`modules/vpn.nix` is currently commented out for the Oracle outage, Tailscale was the only away-from-home path to Jellyfin, so this was a live gap, not theoretical.
- Added `tailscale0.allowedTCPPorts = [ 8096 ]` to the existing firewall block (`daea421`); left DLNA/SSDP discovery LAN-only since it's broadcast/multicast and doesn't cross Tailscale anyway.
- Advised on Jellyfin's dashboard-side "LAN Networks" setting (not flake-managed): `10.0.0.0/24,100.64.0.0/10` — the LAN subnet plus Tailscale's whole CGNAT range, so Tailscale clients get local-quality treatment and future tailnet devices don't need a dashboard edit. User applied it themselves.

### Decisions
- Recommended the Tailscale CGNAT block (`100.64.0.0/10`) over individual peer IPs for the LAN Networks setting — covers current and future tailnet devices with one entry.

### Issues / surprises
- None — clean root-cause, clean fix, clean verification.

### Next session
- Nothing pending on this thread. If wg0/vpn-server comes back, its existing `wg0.allowedTCPPorts` rule is already in place and needs no changes.

**Commits**: `daea421` (1 commit)

---

## Session: 2026-08-18 — Tailscale mesh completed (all 5 devices), pi-hole/famdash SSH fully fixed, DNS rerouted through pi-hole over Tailscale, VPN watchdog silenced

**Focus**: Finish the Tailscale rollout, close out pi-hole/famdash SSH reachability, route desktop DNS through pi-hole over the mesh, and stop the now-purely-noisy VPN watchdog. (2 more back-to-back sessions closed together, same day as the previous close.)

### What changed (and why)
- User finished the Tailscale rollout: rebuilt laptop/natalie-laptop and ran `sudo tailscale up` on each; installed Tailscale manually on pi-hole and famdash (non-flake, console-managed). All 5 devices confirmed live via `tailscale status` and the admin website — closes out session 81's top pending item.
- Fixed pi-hole/famdash SSH in two parts: repointed `ssh.nix`'s aliases at their stable Tailscale IPs instead of drift-prone LAN IPs (`910a2d9`), then fixed the separate, longstanding key-trust denial by manually appending gaming's key to each Pi's `authorized_keys` via console (`a5a400d`). Both now connect cleanly from gaming.
- Rerouted desktop DNS from pi-hole's LAN IP to its Tailscale IP (`30c73ee`) so filtered DNS keeps working for laptop/natalie-laptop off the home LAN — chosen via a short `/interview` (Option B: flake-managed swap) over a Tailscale admin-console DNS override (Option A). Pre-flight caught pi-hole's own `listeningMode = "LOCAL"` silently dropping tailnet-sourced queries; fixed to `ALL` with the user's sign-off before touching the flake. Only gaming has switched onto this so far.
- Removed gaming's `vpn-health-check` watchdog entirely (`40cf9a5`) — it was just reliably alerting every 20 minutes on the already-known Oracle outage; stopped the live timer immediately too.

### Decisions
- DNS: Option B (flake-managed nameserver swap) over Option A (Tailscale admin-console override) — deterministic, reuses existing dry-run/deep-eval tooling, keeps a working fallback.
- Flipped pi-hole's `listeningMode` to `ALL` after judging the open-resolver risk acceptable here (no port-forward, Tailscale's own firewall chain still gates non-tailnet traffic) — a real posture change to a live appliance, done with explicit sign-off.
- Tailscale on pi-hole/famdash installed manually rather than retrofit into flake/`new-host` management — consistent with how they've always been treated.

### Issues / surprises
- pi-hole's default `listeningMode` almost silently killed the whole DNS-over-Tailscale change — caught by a pre-flight query test before editing the flake, not after.
- The old "pi-hole bypassed during VPN tunnel" gotcha is currently moot (wg0 is out of the flake) but will need re-verifying against the new Tailscale-IP nameserver once wg0 is restored.

### Next session
- laptop/natalie-laptop: `nh os switch` to apply the pi-hole-over-Tailscale DNS change (verified clean, just needs applying).
- Once vpn-server is back: restore wg0 (5 commented-out spots) and re-check the pi-hole-bypassed-during-VPN interaction against the new Tailscale-IP nameserver.
- Check whether Pinchflat downloads are still working with wg0 down — still unverified.

**Commits**: `910a2d9..40cf9a5` (4 commits: `910a2d9`, `a5a400d`, `30c73ee`, `40cf9a5`)

---

## Session: 2026-08-18 — vpn-server outage root-caused (Oracle-side, no ETA); Tailscale stopgap expanded to all 3 hosts; wg0 pulled from the flake; improve-system swept 60 skills

**Focus**: Diagnose why vpn-server was completely unreachable, ship a stopgap, then stabilize the fleet against the ongoing outage — plus the day's second `improve-system` pass. (4 back-to-back sessions closed together.)

### What changed (and why)
- Diagnosed vpn-server's total unreachability via `oci-cli`: Oracle administratively disabled the instance (`409 IncorrectState` on every action) and separately cut the tenancy's Always-Free A1 quota from 4/24 to 2/12 OCPU/GB. Not fixable via the API or from this repo — drafted Support-ticket text and handed it to the user; no automated "tell me when it's back" watcher built (declined — see Decisions).
- Shipped Tailscale as an interim mesh stopgap: gaming first (`23e4fbd`, confirmed connected via `tailscale status`), then expanded to laptop + natalie-laptop (`34b9e72`, deep-eval verified, actual rebuild+auth left to the user — sudo-gated). Mesh-only, manual auth, doesn't reproduce wg0's egress-IP masking.
- Pulled `modules/vpn.nix`/wg0 out of `desktopModules` entirely (`5b1ad16`, commented out not deleted) so no host files a failing `wg-quick-wg0` unit at boot while there's no working endpoint — also commented out the now-orphaned per-host `wg0.address` fragments and gaming's Pinchflat split-tunnel bypass that existed solely to support it.
- Ran a second `improve-system` pass (`443fb9a`): `skill-upgrade` fixed 2 real misfires (`save-memory`'s bare template path, `wayland-screenshot`'s SSH-to-remote-host failure); `skill-audit` swept all 60 skills via 5 parallel agents, found and fixed 6 issues (3 verified bare-`scripts/...`-path bugs, an `AskUserQuestion` gap in `new-module`, an asset extraction in `repo-creator`, plus 2 new permission-allowlist entries); `skill-suggestion`/`agent-suggestion`/`claude-rules` all came back clean.

### Decisions
- Comment-out over delete for wg0/vpn.nix — it'll reconnect on its own once vpn-server is back, no re-wiring needed.
- Tailscale expansion kept to the same manual-auth, mesh-only scope as gaming's stopgap — 3 ad-hoc hosts doesn't justify a sops `authKeyFile` yet, and exit-node/egress-masking stays explicitly deferred.
- Declined building a vpn-server recovery watcher — the existing health-watchdog only fires on further outages, not recovery; user chose to self-watch for Oracle's reply instead.

### Issues / surprises
- Pinchflat's download bot-detection bypass depended on wg0's full-tunnel egress masking, which Tailscale mesh doesn't provide — flagged as a likely-broken-again gap, not verified either way this session.
- A later `nh os switch` on gaming (inside the Tailscale-gaming session) very likely brought `443fb9a` and the prior session's `4feaa11` live in `~/.claude` too, inferred from the git-tree-builds-everything-committed reasoning rather than individually re-confirmed file-by-file.

### Next session
- laptop/natalie-laptop: `nh os boot`/`switch` + `sudo tailscale up` to complete the 3-host mesh.
- Check whether Pinchflat downloads are still succeeding with wg0 down.
- Once vpn-server is back: restore wg0 (grep `vpn.nix`/`wg0` across the 5 commented-out spots) and verify via `shared-module-check`.

**Commits**: `443fb9a..5b1ad16` (4 commits: `443fb9a`, `23e4fbd`, `34b9e72`, `5b1ad16`)

---

