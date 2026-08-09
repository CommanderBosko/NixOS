# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-08-09 — Full skill-ecosystem sweep (58 skills, 5 bugs fixed) + flake update

**Focus**: Chain `/skill-suggestion` → `/skill-upgrade` → `/skill-audit` across the whole skill roster, plus a routine `/flake-update-verify` and weekly-PR check.

### What changed (and why)
- **`/flake-update-verify` ran twice** — first pass reverted (nixpkgs `f13ff45a` still blocked by the removed Sweet-Dark theme, 3rd consecutive blocked run); second pass pinned nixpkgs and updated `dms`/`financeguru`/`home-manager` independently. Verified via `flake-check` + 4-host deep-eval, committed+pushed (`e6b8367`).
- **`skill-suggestion`** scanned 66 transcripts since 2026-07-18: no new skill candidates cleared the reuse bar — nothing invented just to have output.
- **`skill-upgrade`** found 3 genuine misfires and added gotchas to `add-secret` (bare `openssl` not on `PATH`), `session-closer` (`uptime -p`/`-s` fail on this host, use `who -b`), `journal` (`vpn-server` has no `~/.ssh/config` alias).
- **`skill-audit`** swept all 58 skills via 5 parallel sub-agents and found 5 real correctness bugs — a bare-`scripts/` 404 in 6 skills, `rollback`'s false `nh`-rollback claim, `review-improve-system-pr`'s dead PR-search query, `/update`'s missing nixpkgs-pin check, `new-host`'s un-substituted state-version placeholder — all fixed, empirically verified, committed (5 commits), and pushed.
- **`review-improve-system-pr`** checked for the weekly cloud routine's PR — none open, expected before the 2026-08-10 scheduled run.

### Decisions
- Nixpkgs pin stays **temporary** for a 3rd consecutive blocked run — user declined making it permanent again; expected to keep recurring until upstream restores `sweet`/`gtk-engine-murrine` or the theme is migrated.
- All 5 skill-audit findings were implemented in the recommended fix order, nothing declined this time (unlike the 2026-07-30 sweep's Tier-4 skip).

### Issues / surprises
- This session's own `skill-audit` Step 0 hit the exact slash-command transcript-cutoff bug it went on to fix — reported cutoff read 2026-07-18 against a real last-audit of 2026-07-30/08-03. Propagated the fix (already known from `session-closer`'s own Gotchas) to the 3 meta-skills that lacked it.
- This close's own transcript scan hit the same known gap (tool-reported cutoff 2026-08-03 vs. the real last close at `f357132`, 2026-08-08) — cross-checked against `git log`'s `chore(session)` baseline per the documented workaround, so only the two genuinely-new transcripts (today's flake-update-verify run and the skill-suggestion/upgrade/audit chain) were mined.

### Next session
- `nh os switch` on gaming — brings live the VPN watchdog timer (session 69), today's flake bump (dms/home-manager), and confirms `notify-send` actually fires.
- `nh os boot` + reboot on gaming — brings the 8 global-skill fixes from today's audit live in `~/.claude`.
- `nh os boot`/`switch` + reboot still pending on laptop/natalie-laptop for the pi-hole DNS fix and niri media-key fix (carried over from session 69, unchanged this session).

**Commits**: `f357132..87561de` (6 commits)

---

## Session: 2026-08-08 — Weekly PR review, DNS drift fix, niri media keys, vpn-server MTU + watchdog, router research

**Focus**: Catch-up close spanning five sessions since the last close (2026-08-03 → 2026-08-07) — a weekly skill-sweep PR merge, a flake bump, a real DNS outage-drift bug, a niri media-key UX fix, a non-obvious VPN MTU bug, a new monitoring pair, and a router-architecture research pass in a sibling repo.

### What changed (and why)
- **Weekly `improve-system` PR #6 merged** (`00ab3f1`) — first full live run of `review-improve-system-pr`: guardrail passed, diff reviewed, user-confirmed, squash-merged. Removed a stale `audit-config` carve-out and hardened `rollback`'s confirm gate.
- **`financeguru` flake input bumped** (`21b848e`) — routine lock-only bump.
- **pi-hole/famdash IP drift fixed after a power outage** (`ac1c4ad`) — both Pis re-leased, famdash landed on pi-hole's old slot; verified live (mDNS/HTTP/DNS fingerprinting) before fixing. Surfaced a real bug in the fix itself: the LAN DNS resolver hardcoded in `desktop-networking.nix` had silently become famdash's address, bypassing pi-hole ad-blocking fleet-wide since the outage.
- **niri media keys now route to the most-recently-active MPRIS player** (`8feeb46`) — `playerctld` added at niri startup, matching KDE Plasma's pause/play behavior, across all 3 niri hosts in one shared-config edit.
- **vpn-server MTU black-hole bug fixed** (`d00e0fd`) — root cause of user-reported "random gaming stutter" through the VPN: Oracle's route cache over-reports MTU 9000, so `wg-quick` auto-detected `wg0` at 8920 with no explicit clamp, causing return traffic to fragment and silently drop. Added the same `mtu = 1380` clamp the client side already had. Confirmed live.
- **Gaming-only VPN health-watchdog + a cloud nixpkgs-staleness routine added** (`1a4d440`) — a follow-up audit found vpn-server had no monitoring and no automated patch-cadence check; built a local systemd timer for the former (dry-run clean, not yet switched) and a cloud routine for the latter (first run 2026-08-10).
- **Router research done, written to a sibling repo** — `~/projects/home-lab/docs/router-options.md` (not this repo) now recommends running NixOS itself as a future home router, for the same declarative/Claude-drivable reasons this repo already exists. No hardware bought, nothing scaffolded here.

### Decisions
- VPN monitoring split into a local watchdog (live health, needs SSH) + a cloud routine (staleness check, no credentials needed) rather than one combined mechanism — the cloud sandbox genuinely can't reach vpn-server.
- NixOS-as-router chosen over OPNsense/VyOS/an appliance specifically for *this* user's declarative/AI-manageable priority axis, not as a general "best firewall" verdict — see `project-state.md` for the full tradeoff.

### Issues / surprises
- Live-verified during this close that pi-hole ad-blocking is bypassed by design whenever gaming's VPN tunnel is up — `wg-quick`'s own `DNS=` setting overwrites `/etc/resolv.conf` for as long as the tunnel is connected, independent of the LAN nameserver fix above. Not a bug, but worth knowing before re-diagnosing a future "pi-hole isn't blocking anything" report.
- This close's transcript scan pulled in two already-closed 2026-08-03 sessions (`967aef9`, `cb5380d`) due to the known slash-command-cutoff-detection gap — cross-checked against `git log`'s actual last `chore(session)` commit and excluded their content from this narrative rather than re-describing already-documented work.

### Next session
- `nh os switch` on gaming to bring the VPN watchdog live, then confirm it actually fires (e.g. point it at a bad host temporarily).
- `nh os boot`/`switch` + reboot on laptop and natalie-laptop for the pi-hole DNS fix and the niri media-key fix — both are gaming-only confirmed live right now.
- No action required on the router research unless the user decides to move forward with buying hardware.

**Commits**: `21b848e`..`1a4d440` (7 commits: `21b848e`, `2ed3644`, `00ab3f1`, `ac1c4ad`, `8feeb46`, `d00e0fd`, `1a4d440`)

---

## Session: 2026-08-03 — Pinchflat VPN split-tunnel fix (bot-detection root cause)

**Focus**: Diagnose and fix Pinchflat's yt-dlp downloads failing with YouTube's "Sign in to confirm you're not a bot" error, which the user suspected was VPN-related.

### What changed (and why)
- Confirmed the user's hypothesis directly rather than guessing: gaming's WireGuard client is a deliberate full tunnel, so Pinchflat's yt-dlp traffic was exiting via the Oracle Cloud VPS IP — `curl -4 ifconfig.me` from gaming literally returned the VPN server's own address, a datacenter/hosting ASN YouTube flags far more aggressively than residential IPs.
- **Fix 1** (`61fe874`): a UID-scoped `ip rule` (via `wg-quick`'s `postUp`/`postDown`) routes only Pinchflat's traffic via the normal LAN gateway, bypassing wg0, while the rest of gaming stays fully tunneled. UID resolved at *runtime* (`$(id -u pinchflat)`), not eval time — NixOS system users get dynamically assigned UIDs.
- **Fix 1 alone hung every connection in `SYN-SENT` forever** — a second, non-obvious bug: NixOS's firewall does its own strict reverse-path check independent of the `rp_filter` sysctl (already loose), and dropped the return traffic as spoofed since the global route still points at wg0. **Fix 2** (`4fad567`): `checkReversePath = "loose"` on gaming, matching a pattern `vpn-server` already used for the same class of asymmetric-routing problem.
- Confirmed fully live end-to-end, not just dry-run-clean: all 3 previously-failing videos downloaded successfully (video, thumbnail, `.nfo`, `.info.json` all present in `/mnt/media/YouTube`) — Pinchflat's first-ever confirmed successful download.

### Decisions
- UID-scoped split-tunnel exception over disabling full-tunnel entirely or relying on cookies (yt-dlp's own suggested workaround) — cookies treat the symptom (still flagged as a datacenter IP) not the cause, and full-tunnel is deliberate for the rest of the host.

### Issues / surprises
- The two-part nature of this fix was the real surprise: the routing rule alone doesn't error, it just hangs silently (`SYN-SENT` forever) — easy to mistake for "still propagating" rather than a second real bug. Root-caused via `ss -tn state syn-sent` plus a control test (a plain `curl --interface enp4s0` as a different, non-pinchflat user reproduced the identical hang, which ruled out anything specific to the UID rule itself).
- `ps aux` intermittently failed to show other users' full command lines for the pinchflat-owned yt-dlp processes, while `pgrep -u pinchflat -a` and `ps -p <pid> -o cmd` did — cost some back-and-forth before finding the actually-running (but network-stalled) processes.

### Next session
- Set up the Jellyfin "YouTube" library and confirm the Media Profile's NFO/series-image toggles — now higher priority, since 3 real video files are already sitting in `/mnt/media/YouTube` with no library to pick them up.
- Watch for Yes Theory's next upload (still gated by its own unrelated `download_cutoff_date`) as the first real end-to-end file-to-Jellyfin verification.

**Commits**: `61fe874`..`4fad567` (2 commits)

---

## Session: 2026-08-03 — Pinchflat YouTube archiver added to gaming, wired to Jellyfin

**Focus**: Research, plan, and deploy Pinchflat (self-hosted YouTube archiver) on gaming, integrated with the existing Jellyfin library. Also closes a gap of several unclosed prior sessions.

### What changed (and why)
- `/research` (9 sources) found nixpkgs already ships a native `services.pinchflat` module — no Docker needed. Built `hosts/gaming/pinchflat.nix`: `mediaDir` on a new `/mnt/media/YouTube` folder sharing Jellyfin's existing `media` group, port 8945 firewalled LAN+WG (matches Jellyfin's own scoping), `SECRET_KEY_BASE` via a new sops secret rather than the module's weak `selfhosted` escape hatch. `nixos-dry-run` clean (+367 MiB, no kernel/DM changes), committed `b76e09b`, pushed.
- **Confirmed live this close**: gaming got a full reboot (15:11) + switch (15:31) today — verified directly (`systemctl status pinchflat`, `/mnt/media/YouTube` perms, HTTP 200 on :8945) rather than assumed. That same reboot+switch also activated a large backlog from several previously-unclosed sessions (see below).
- Added first source (Yes Theory) and hit two real Pinchflat gotchas, both root-caused live: a `download_cutoff_date` that correctly filtered out all current videos (working as designed, not a bug — user wants future-only), and a `collection_type: playlist` misdetection matching a confirmed-still-open upstream bug (`#607`) that survived re-adding with two different URL forms — accepted as-is (cosmetic-only impact).
- Resolved several practical follow-ups: SponsorBlock ("mark chapters" only, non-destructive — enabled), "use my subscriptions as a source" (not possible, and the cookie-auth workaround is explicitly discouraged upstream), and the new Jellyfin "YouTube" library's advanced settings (decided, not yet applied).
- **Catch-up**: ten commits across several separately-run, unclosed sessions since the 2026-07-30 close — flake bump, a VPN weekly-reboot timer, Jellyfin's `UMask` fix (which this session's Pinchflat work directly relies on), a `cups-browsed` boot-race fix, and six skill-doc gotcha additions. Narrated from commit messages only.

### Decisions
- Native nixpkgs module over Docker; shared Jellyfin `media` group over a standalone `pinchflat` group; sops secret over `selfhosted = true` — all three keep Pinchflat consistent with how the rest of this repo already does things, rather than treating it as a one-off appliance.
- Accepted both Pinchflat rough edges (playlist misdetection, cutoff-date filtering) rather than chasing them further — neither blocks real functionality.

### Issues / surprises
- The `nh os boot --dry` gotcha recurred (untracked file invisible to flake eval) — `git add`-ing the new files before dry-running fixed it immediately, but worth remembering it'll happen again for any new host file that isn't staged first.
- Generation bookkeeping looked alarming at first (a new generation appeared to be created at the same moment as a `--dry` run) — turned out to be the user running the recommended `sudo nh os switch` a few minutes later, not the dry-run itself doing anything live. Worth double-checking generation timestamps precisely (to the second) before concluding a "read-only" skill did something it shouldn't have.
- A second Pinchflat source (`@66Samus`) was found already mid-indexing, added directly through the web UI outside this conversation — no context on it beyond what's visible in `systemctl status`.

### Next session
- Confirm the Pinchflat Media Profile has NFO/series-image toggles on, and actually create the Jellyfin "YouTube" library with this session's decided settings — do this before Yes Theory's next upload lands.
- Check back once Yes Theory (or `@66Samus`) posts something new — first real end-to-end file-to-Jellyfin verification is still pending.
- laptop/natalie-laptop still need their own rebuild+reboot to pick up everything gaming got today (docx/CIFS fixes, skill fixes, etc.) — not part of this session's scope.

**Commits**: `896eca9`..`b76e09b` (11 commits, spanning this session plus the unclosed catch-up range)

---

## Session: 2026-07-30 — Skill-audit sweep, tray-icon dead end, docx/portal/CIFS fixes

**Focus**: Full skill-library quality sweep, plus a batch of desktop/networking fixes carried over from the tail end of 2026-07-29.

### What changed (and why)
- **`/skill-audit`** swept all 58 skills via 5 parallel sub-agents: 3 real correctness bugs fixed (`remote-rebuild`'s broken sudo hand-off, `skill-audit`'s own self-contradicting Step 1, `session-closer`'s stale doc numbers) plus 4 style fixes (`vpn-status` IP dedup, `repo-creator` AskUserQuestion gate, `claude-rules` script extraction, `create-secret-scan` Arguments section). Declined one recommendation (`public-repo-guard`'s inline template) after confirming it's the intentional repo-wide loop-skill convention.
- `nixos-dry-run` now recommends `switch` vs `boot` from the diff content. `skill-suggestion`/`skill-upgrade`/`skill-audit` now scope their transcript scan to "since I last ran" via two new shared helpers — this also caught and fixed a real bug in `session-closer` itself (its transcript scan only ever read the latest `.jsonl`, contradicting its own docs).
- New skill `printer-diagnose`, automating a diagnostic sequence done by hand 4+ times across sessions. Smoke-tested live on gaming.
- **Tray-icon dead end**: added `snixembed` to bridge Wine's XEmbed tray icons into DMS's SNI tray, then found live it breaks DMS's tray entirely (exclusive-watcher conflict) — reverted same day.
- **docx/odt mimetype fix** (was wrongly routed to xarchiver, not OnlyOffice) — confirmed live on natalie-laptop after `nh os switch`. **niri ScreenCast/Screenshot portal fix** (was routed to gtk, which doesn't implement those interfaces; now gnome) — confirmed live on gaming. A separate stuck-file CIFS issue was worked around (fresh inode), root cause not found.
- **gaming's static IP confirmed live** after reboot. **CIFS bare-hostname resolution fixed** for the `/srv/shared` mount (`mdns4_minimal` doesn't resolve bare hostnames).

### Decisions
- Declined `public-repo-guard`'s template extraction — matches `create-loop`'s settled self-contained-loop design, not a real deviation.
- No packaged alternative to `snixembed` exists in nixpkgs (`xembedsniproxy` isn't packaged) — Battle.net's tray icon stays a floating window rather than chase a different bridge.

### Issues / surprises
- My own `scan-session.sh transcript | head -c 60000` truncated the real scan output to 3 of 17 transcripts — no bug in the script itself, just my own piping. Worth remembering: don't cap this command's output when reviewing a multi-session close.
- The transcript-scan cutoff (`find-last-skill-invocation.sh session-closer`) returned a timestamp a full day stale relative to the actual last `chore(session)` commit — harmless here (the wider window just re-surfaced already-closed sessions 64/65's worth of content redundantly), but worth watching if it recurs.

### Next session
- Run `nh os switch` for the skill-audit global-skill fixes (no reboot needed).
- laptop: `nh os switch` to pick up the docx mimetype fix and the CIFS hostname fix (natalie-laptop already confirmed).
- Confirm the fresh-inode workaround holds for `mock-interview-questions.docx`; watch for recurrence on other `/srv/shared` files.

**Commits**: `812aa5f`..`3db5168` (13 commits)

---

