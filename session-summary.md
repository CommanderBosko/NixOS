# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-08-20 — Boot error triage on laptop (shared folder + bluetooth fixes)

**Focus**: Triage a vague "saw some errors on boot" report on laptop into root-caused fixes.

### What changed (and why)
- Ran `/boot-error-triage`, filtered ~130 lines of known-benign `dbus-broker`/`gkr-pam` noise, and root-caused the 3 real candidates left: a failed `srv-shared.mount`, an ACPI BIOS firmware bug, and a bluetooth ISO-socket warning.
- `modules/shared-folder-client.nix` (`693d573`): switched the `gaming` `extraHosts` entry from its LAN IP (`10.0.0.251`) to its Tailscale IP (`100.66.15.1`), so `/srv/shared` also resolves off the home LAN — same pattern already used for Jellyfin.
- `hosts/laptop/environment.nix` (`fc756c3`): added bluez's `KernelExperimental` ISO-socket UUID alongside the existing `Experimental = true`, fixing the "BAP requires ISO Socket which is not enabled" warning so LE Audio codecs become available.

### Decisions
- Corrected the user's initial framing before acting: the CIFS mount failure wasn't an IP misconfiguration (the static IP was already correct and live) — `gaming` was simply powered off. Verified via LAN ARP + Tailscale status before proposing any fix, then asked what they actually wanted (switch to the Tailscale IP, which they confirmed).
- Left the ACPI BIOS errors alone — confirmed via kernel.org Bugzilla #220583 as an upstream ASUS firmware bug (DSDT references a missing EC symbol), and confirmed live that the only functional impact is `sensors` can't read fan RPM; thermal management itself is unaffected. No kernel-side fix exists.

### Issues / surprises
- Both boot fixes verified clean on the first pass (`nixos-dry-run` + `shared-module-check`'s 4-host sweep, since the shared-folder file is shared with natalie-laptop).
- The session-close `secret-scan` pass hit a real bug in the skill itself: `git rev-list --all --exclude=refs/stash` silently ignores `--exclude` because it comes after `--all` (git only honors it when it's first) — a prior session's "fix" for this exact class of false alarm had the flags in the wrong order the whole time. Root-caused to 13 stale, worthless local stashes (pre-sops-migration, ~2026-05-21) leaking an old plaintext password hash back into the scan. Fixed the flag order, and — after confirming with the user — dropped all 13 stashes. Also pruned 5 already-deleted-on-GitHub branches' stale local tracking refs that were contributing the same way. Scan is clean now.

### Next session
- laptop needs its own `nh os switch` to apply both fixes (config-only, no reboot). natalie-laptop needs a switch too, to pick up the shared Tailscale-IP change.

**Commits**: `693d573..fc756c3` (2 commits) + this close's own `secret-scan.sh` fix

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

