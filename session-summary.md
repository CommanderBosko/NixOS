# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-10-24 (session 139) — Proton/Vesktop boot and stall fixes, sixth rule

**Focus**: Close out four conversations: three fixes that make Proton VPN and the Vesktop bypass survive a cold boot, plus a new standing rule (PR #55).

### What changed (and why)
- **Firewall no longer dies at boot (`d926620`, PR #52):** Vesktop's cgroup rule ran before `user@1000` created `app-novpn.slice`, so `firewall.service` failed on two cold boots and gaming ran with no firewall until a manual restart. The rules now live in `vesktop-direct.service`, ordered after login, with the slice as a login-time user unit. Verified on the 16:03 cold boot.
- **Proton tray icon (`741a092`, PR #53):** the app checked once for the tray watcher and lost the race with DMS/quickshell; the autostart now waits (≤30 s) for it. Verified after the 08:01 boot.
- **Proton stuck at "Connecting" (`4274364`, PR #54):** api-core 5.2.5 missed NM's activation signal when WireGuard came up first; patched to start the local agent if already activated. Live on gen 472, not yet proven (intermittent).
- **Sixth standing rule (`2a44c82`, PR #55, open):** "Read Everything Before Editing". A "Supervisor, Not Builder" rule was added and removed in the same conversation.

### Decisions
- Late-start rules service over `|| true` or a gid match; a package patch over a watchdog; Supervisor dropped as overhead.

### Issues / surprises
- The boot-order bug hid because gen 467 was switched live with the slice already present.
- Hermes's tray-wait draft did not evaluate on the first try; no token saving on small Nix edits.
- The live `~/.claude` still has the seven-rule version until PR #55 merges and a host rebuilds.

### Next session
- Land #55 and rebuild; watch Proton over several boots; carry-overs from 138.

**Commits**: `2c9c8ed..2a44c82` (9 commits, 4 of them merges)

Secret-scan: clean (tree + 1,911 commits, all `secrets/*.yaml` encrypted).

---

## Session: 2026-10-22 (session 138) — land the Proton VPN and rebuild-host PRs

**Focus**: Make `rebuild-host` real: the user still saw `rebuild-natalie-laptop` because its replacement was sitting in an unmerged PR.

### What changed (and why)
- **Alias mixup:** the report named `reboot-*`, but the user meant `rebuild-*`. `reboot-host` was fine on gaming and natalie-laptop; `rebuild-host` lived only on unmerged PR #48, so `main` and the live system still defined the old alias.
- **Landed PRs #48, #47 and #50** with `land-prs` (merge commits `cdc8b87`, `3c16bbe`, `360300a`). #50, the morning's session close, went in first-of-this-close because it edits the same state files. Merging #47 was approved before the user spotted a worry that it drops the Proton VPN GUI; it does not (the CLI was added and reverted inside it, net GUI only), but the interrupt arrived after the merge.
- **Dry-run from `main`:** builds clean for gaming, +13/-13 paths, +5.38 KiB, recommendation `switch`. The user then ran `rebuild-switch` (gen 468, 08:54) and confirmed `rebuild-host` is live; the apply stayed with the user.

### Decisions
- Landed #50 before writing this close rather than stacking on its branch or skipping, so the state files don't conflict.
- Left the remote `chore/session-close-20261022` branch undeleted: the delete wasn't confirmed.

### Issues / surprises
- laptop timed out over SSH, so its state is still unknown.
- The merge happened before the user's concern about #47 landed; worth re-confirming scope immediately before an irreversible merge when the user is mid-thought.

### Next session
- First real `rebuild-host natalie-laptop`; pull + rebuild laptop; restart Vesktop if not already.

**Commits**: `cdc8b87..360300a` (3 merge commits; the underlying work is in sessions 136-137)

Secret-scan: clean (tree + 1,901 commits, all `secrets/*.yaml` encrypted).

---

## Session: 2026-10-22 (session 137) — Proton autostart, Vesktop bypass, qBittorrent leak

**Focus**: Make Proton VPN usable day to day on gaming: start at login, keep Discord working, and stop torrent traffic leaking.

### What changed (and why)
- **Autostart (`e3fa102`):** a system-wide XDG autostart entry runs `protonvpn-app --start-minimized` for every user on the three desktops. Hermes drafted it, Claude reviewed and deep-evaled it. After a reboot the app started in the tray and auto-connected.
- **Vesktop outside the tunnel (`4461aaf`, `hosts/gaming/vesktop-direct.nix`):** Discord's edge returns 403 / code 40333 to browser-style API requests from Proton exit IPs (two exits tested), so no messages loaded. Vesktop now runs in `app-novpn.slice`; its packets get a fwmark routed out the LAN with masquerade, replies are exempted from the strict rpfilter, and its IPv6 is rejected. Verified live on gen 467: Discord API 200 from the slice, everything else still on Proton.
- **qBittorrent leak (outside the repo):** it listened on every interface and its log recorded the home IP. Bound it to `proton0` in its config; sockets and log now show only Proton addresses, and with the VPN down it sends nothing.
- **Advice only:** port forwarding, Moderate NAT and IPv6 left at defaults; custom DNS can't be declarative and is probably moot because DNS goes Tailscale → pi-hole. Proton Drive stays on hold (no official Linux client; `proton-cli` is community). `MEMORY.md` trimmed from 20 KB to 16.4 KB.

### Decisions
- Bypass Vesktop with a narrow per-cgroup route rather than loosening `checkReversePath` host-wide; the price is that Discord sees the home IP.
- Autostart for every user, not just bosko.

### Issues / surprises
- This close ran on `feat/proton-vpn`, whose history lacks the 10-21 close (it merged to `main` as PR #49), so `scan-session.sh git-changes` picked the 10-20 close as baseline. The docs were written in a worktree off `origin/main` instead so they don't conflict with PR #47.
- Phone connectivity under Proton is unresolved; DNS and Tailscale behavior with the tunnel up is still untested.

### Next session
- `land-prs` #47 (CI was still running) and #48, rebuild laptop and natalie-laptop, test pi-hole DNS + Tailscale with Proton connected.

**Commits**: `e3fa102..4461aaf` (2 commits on PR #47's branch, unmerged at close)

Secret-scan: clean (tree + 1,896 commits, all `secrets/*.yaml` encrypted).

---

## Session: 2026-10-21 (session 136) — Proton VPN via Hermes, `rebuild-host`

**Focus**: Install Proton VPN on the three desktops (Hermes drafts, Claude reviews), then generalize the rebuild alias.

### What changed (and why)
- **PR #47, `modules/proton-vpn.nix`:** installs the Proton VPN GUI on gaming, laptop and natalie-laptop via `desktopModules`. Hermes wrote it in its sandbox clone with the commit/push steps forbidden in the prompt; Claude cut its duplicated comments and ran the 4-host deep-eval. gnome-keyring is already on for all three, which the client needs.
- **CLI added, then reverted:** `proton-vpn-cli` co-installs cleanly, but Proton says not to run both at once. The user preferred the GUI, so it was reverted with a revert commit (no force-push).
- **PR #48, `rebuild-host <host>`:** the `rebuild-natalie-laptop` alias became a function like `cleanup-host`/`reboot-host`, so any desktop can be built here and staged for next boot.

### Decisions
- Hermes writes drafts only in the sandbox clone and never commits; Claude reviews and lands them via PR.
- GUI only; the CLI stays out.

### Issues / surprises
- A branch cut from `origin/main` tracks `main`, so `push.sh execute`'s plain `git push` failed and `| tail` hid it; pushed with `-u origin <branch>`.
- Untested: pi-hole DNS and Tailscale behavior while Proton is connected.

### Next session
- Merge #47 and #48, rebuild, then test Proton + pi-hole + Tailscale on gaming.

**Commits**: `de4ffdc..c3c2cca` (4 commits on two PR branches, unmerged at close)

Secret-scan: clean (tree + 1,892 commits, all `secrets/*.yaml` encrypted).

---

## Session: 2026-10-20 (session 135) — Hermes hardening, protected main, competency test

**Focus**: Close-only. 12 conversations since the 10-19 close hardened Hermes on gaming, protected `main`, and built a Hermes test suite.

### What changed (and why)
- **Mnemosyne made declarative** (`7aaddad`, `70b41d8`, `994b558`): Hermes had half-installed its own memory provider imperatively and reported it working when it wasn't. Now a flake input, installed at `plugins/mnemosyne`, and every free-text Mnemosyne writer goes through the memory checker (`980bd7d`, `b7d3efa`).
- **Hermes gates** (`3d9f0d0`, `006c38c`, `f183040`): write-safe root, manual approvals, staged skill creation, `gh pr merge*` denied, repo `AGENTS.md`. Follows the Hermes-improvement research: safety and context hygiene beat new plugins.
- **`main` ruleset-protected, no bypass** (PR #41): Hermes shares bosko's unlocked ssh-agent and `gh` login, so only a server-side rule really stops a push. `push.sh` now falls back to a PR branch.
- **Superpowers + Ponytail dropped from Claude** (PR #43): overlap and conflict with the CLAUDE.md rules, plus per-session token cost.
- **`hermes-competency-test` skill** (PR #44, open): 31 items × 3 repeats, trust tiers, canary, noise floor, supervised ssh stage; keys kept outside git.

### Decisions
- Hermes may push branches and open PRs but not merge; ssh stays allowed with manual approval for networking help.
- The test drives Hermes in single-query mode because `hermes -z` auto-approves anything not denied.
- `mnemosyne_import` blocked; Mnemosyne not wired into Claude Code.
- Calibration and baselines paused for Claude token budget until the week of 10-26.

### Issues / surprises
- A `git reset --hard` after a push probe wiped uncommitted edits (redone; now a feedback memory).
- Hermes's own Mnemosyne install overclaimed success; its checker's 3 `KeyError`s were usage-limit fail-opens (stores audited clean).
- Every `hermes` run prints "install out of sync": upstream #134249, cosmetic.

### Next session
- `land-prs` #44 and this docs PR; then calibrate + two full baselines; `/fleet-rollout` laptop + natalie-laptop.

**Commits**: `7aaddad..4944fc4` (11 commits; `4944fc4` is on PR #44's branch)

Secret-scan: clean (tree + 1,881 commits, all `secrets/*.yaml` encrypted).

---

