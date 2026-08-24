# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-08-23 — No-op close (immediate re-run after prior close)

**Focus**: `/session-closer` was invoked again right after the same-day close below, with no
work done in between — a review/no-op session, not a coding one.

### What changed (and why)
- Nothing. `git status` clean, no commits since the `8915985` baseline (itself this same
  day's prior close). `project-state.md` and `README.md` are left as-is since nothing
  changed since they were last refreshed a few minutes earlier.

### Next session
- Same open items as the prior 2026-08-23 entry below (rebuild to bring `3230dfd` live,
  apply the `041a0d1` flake bump + pending `ssh.nix` switch).

**Commits**: none (clean tree)

---

## Session: 2026-08-23 — Research-skill memory feature, flake bump, gaming boot re-triage

**Focus**: Make `/research` persist its findings to memory (with prior-research cross-referencing and a staleness tag); catch-up close for a same-arc flake bump, a clean gaming boot triage, and a live WarDogs crash diagnosis.

### What changed (and why)
- `dotfiles/bosko/claude/skills/research/SKILL.md` (`3230dfd`): Step 2 now checks the project's memory dir for a prior finding on the topic before searching; Step 6 states whether new results reaffirm/update/contradict it; Step 7 persists sources+consensus+coverage to a `reference` memory via `save-memory`, tagged with a judged `Volatility: fast|slow` line so a later stale read can be flagged.
- `dotfiles/bosko/claude/CLAUDE.md` (`3230dfd`): new "Stale Fast-Moving Research Memories" rule — proactively flags a recalled `Volatility: fast` memory older than 90 days as possibly stale.
- `flake.lock` (`041a0d1`, via `/flake-update-verify`): nixpkgs/home-manager/dms bumped, verified clean (flake-check + 4-host deep-eval), committed+pushed lock-only.

### Decisions
- No architectural decisions this session — mostly additive feature work and routine verification.

### Issues / surprises
- `/boot-error-triage` re-run on gaming (testing the new Concise output style) came back clean — same benign AMD IRQ quirk as before, now memory-suppressed from re-flagging; user again declined the BIOS flash.
- A live WarDogs "freeze" turned out to be a `GameThread` SIGSEGV followed by a 2-minute `systemd-coredump` write, not an actual hang — no config change, diagnostic only.

### Next session
- Rebuild + reboot gaming (or any host) to bring `3230dfd`'s research-skill/CLAUDE.md changes live in `~/.claude`.
- Apply the `041a0d1` flake bump and the still-pending `ssh.nix` Tailscale-IP switch (session 87) — both can ride the same rebuild.

**Commits**: `041a0d1..3230dfd` (2 commits)

---

## Session: 2026-08-21 — Repo-wide Tailscale IP sweep

**Focus**: Check the whole repo for old (non-Tailscale) IP addresses that should be using Tailscale IPs instead.

### What changed (and why)
- Grepped the whole repo live for IP-shaped literals (`.nix` files + `.claude/`) rather than trusting memory, then triaged each hit before touching anything.
- `dotfiles/common/configs/ssh.nix` (`2d3ab40`): switched the `laptop` and `natalie-laptop` SSH aliases from their LAN/DHCP IPs to their stable Tailscale IPs (`100.114.0.106`, `100.116.208.93`) — the same drift-prone pattern already fixed for `pi-hole`/`famdash`, and `natalie-laptop`'s LAN IP had already drifted once before (session 30). Also switched `gaming`'s alias to its Tailscale IP (`100.66.15.1`) per the user's call, even though its LAN IP is a static reservation with no drift risk — for consistency and off-LAN reachability.

### Decisions
- Used `AskUserQuestion` to scope two boundary calls rather than assuming: switch `gaming`'s alias too (yes), and update the `new-host` skill's server-template pi-hole DNS reference (no — that host type isn't Tailscale-joined by default).
- Ruled out WireGuard mesh IPs (`10.10.0.0/24`), vpn-server's public Oracle IP, libvirt's bridge, `127.0.0.1`, and historical session-log mentions as out of scope — none are Tailscale-address candidates.

### Issues / surprises
- None — the fix was small and isolated once the repo-wide grep triage was done.

### Next session
- All 3 desktop hosts still need their own `nh os switch` to pick up the new `ssh.nix` aliases (rides along with the already-pending session 86 switches for laptop/natalie-laptop).

**Commits**: `2d3ab40` (1 commit)

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

