# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

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

## Session: 2026-07-29 — Shared network folder for natty and bosko (Samba)

**Focus**: Add a shared folder both natty and bosko can use across the fleet, visible in Thunar.

### What changed (and why)
- First pass (scoped via AskUserQuestion, skipping the full `/interview` ceremony): a plain local group-permissioned `/srv/shared` folder, independently on all 3 desktop hosts, symlinked to `~/Shared` in each home dir. Deep-eval + dry-run clean, committed as `489432a`.
- User then asked mid-close whether it synced across machines; once told each host's copy was independent, said no — wanted it centrally hosted. **Reworked into a real Samba/CIFS setup**: gaming (already the always-on Jellyfin host) serves `/srv/shared` via Samba with guest access; laptop and natalie-laptop CIFS-mount it at the same path, client-side permissions forced to `root:shared 0770` so local group membership governs access regardless of server ownership. Auto-mounts at boot via `x-systemd.automount` + `nofail` so client boots don't hang/fail if gaming is off.
- New `hosts/gaming/samba-shared.nix` (server), new `modules/shared-folder-client.nix` (laptop + natalie-laptop's CIFS mount + `cifs-utils`); `modules/shared-folder.nix` trimmed back to just the shared `users.groups.shared`. `~/Shared` symlink in `dotfiles/common/configs/home.nix` unchanged — same path works for both server and client roles.

### Decisions
- Server host: gaming, over laptop/natalie-laptop, since laptops sleep/travel and would take the share offline.
- Protocol: Samba over NFS, for native Thunar/GVfs network-browsing compatibility on a Linux-only LAN.
- Auth: guest access, no password — accepted as appropriate for a trusted home LAN rather than adding sops-managed credentials.

### Issues / surprises
- `deep-eval-check` failed both times immediately after adding a new module file, with "not tracked by Git" — untracked files are invisible to flake evaluation even without committing; `git add` first, every time.
- The user's mid-session question about sync behavior caught a real scope gap the earlier AskUserQuestion round had technically covered ("not synced between machines" was in the option description) but the user hadn't actually registered until asked directly — worth stating consequences plainly, not just leaving them in option subtext, for architecture-shaping choices like this one.

### Next session
- User needs to run `rebuild` + reboot on **gaming first** (the Samba server), then laptop and natalie-laptop (sudo-gated, their own call). Confirm `samba-smbd` active on gaming, then `~/Shared` + CIFS automount + cross-machine read/write on each client.

**Commits**: see this close's final commit hash below (supersedes `489432a`'s local-only draft, kept in history).

---

## Session: 2026-07-28 — Screenshot-verify reminders + permission allowlist tune-up

**Focus**: User asked what an "ultimate optimal workspace" would look like; turned the answer (tighter verification loops) into a concrete change, then asked for a permissions check as a follow-up.

### What changed (and why)
- Added an explicit numbered "run `/wayland-screenshot` after rebooting" step to the next-steps reminder in `switch-de`, `add-niri-fullscreen-rule`, `add-niri-window-rule`, and `add-niri-keybind` (conditional on its window-rule path) — these skills previously ended at commit with no confirmation the visual result actually landed, even though none of them take effect without a reboot.
- Ran `fewer-permission-prompts`: scanned the 50 most-recent session transcripts across all projects, filtered to genuinely read-only and still-prompting patterns, and added 4 entries to `.claude/settings.json` (`session-closer`'s `scan-session.sh`, `git-commit.sh status`, `push.sh status`, `flatpak remote-info*`). Their mutating siblings (`git-commit.sh commit`, `push.sh execute`, `flatpak run`) were deliberately left gated, along with the entire interpreter/shell-runner category.

### Decisions
- Scoped which skills to touch and how the reminder should read via AskUserQuestion before editing anything (user picked all 4 candidate skills + the explicit-numbered-step style over a soft mention).
- Split the work into two commits (skill reminders vs. permission allowlist) rather than one, since they're unrelated concerns.

### Issues / surprises
- None — small, self-contained change; both commits verified clean before push.

### Next session
- No follow-up required; both commits pushed as part of this close.

**Commits**: `db6bca9`, `926e78a`

---

