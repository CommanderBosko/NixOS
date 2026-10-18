# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-10-18 (session 132) — Hermes Agent attempt 2 live on gaming

**Focus**: Build the Hermes attempt-2 plan and get the `hermes` CLI working against the local model (three conversations).

### What changed (and why)
- **`1b37b3d`:** llama.cpp (CUDA) serves a hash-pinned Qwen3.5-9B IQ4_XS at a 64K context, one slot, q8_0 KV cache, started on demand with `llm-on` / `llm-off`. Hermes comes from the upstream Home Manager module and runs as bosko with state in `~/.hermes`.
- **`d4b6ffb`:** README's stale May Ollama bullet replaced; the plan doc is marked implemented and records why it deviates from step 2.

### Decisions
- Home Manager module instead of the planned NixOS module. The current hermes CLI won't attach to a gateway whose home is owned by another uid, so the shared `/var/lib/hermes` + `hermes` group setup can't work. CLI-only, no always-on gateway.
- Old `/var/lib/hermes` state not migrated: it only held May OpenRouter leftovers.

### Issues / surprises
- First switch: `storage_unavailable`. The service couldn't read a May-leftover `auth.json`, and the stale shell lacked `HERMES_HOME` and the group. A tmpfiles chown rule fixed ownership but led straight into the next error.
- After reboot: `Gateway inaccessible: unsafe_control_path` (uid 986 vs 1000), the root cause above.
- After moving to HM, the old system-wide `HERMES_HOME` lingered in the login session until a re-login.
- Measured at close: 7217 / 8192 MiB VRAM with the desktop up, n_ctx 65536, no OOM.
- Secret-scan: clean (tree + 1853 commits of history; all 6 sops files encrypted).

### Next session
- Hermes plan checks 6–8 (tool calls, long session, `llm-off` frees VRAM), then `sudo rm -rf /var/lib/hermes`.
- Mod+G no-jump check on gaming; `/fleet-rollout` backlog.

**Commits**: `1b37b3d..d4b6ffb` (2 commits)

---

## Session: 2026-10-17 (session 131) — Mod+G no-focus + Hermes Agent attempt-2 plan

**Focus**: Two conversations: stop Mod+G's apps from yanking the monitors, and re-check whether Hermes Agent can run locally on the RTX 3070.

### What changed (and why)
- **Mod+G (`c8062a6`):** `open-focused false` on the Steam, Lutris, Vesktop, Deezer and qBittorrent window rules in gaming's niri overlay, so the startup launch no longer jumps either monitor to each new window. `niri validate` and the dry-run were both clean. It's live on gaming (gen 442), but nobody has watched it work yet.
- **Hermes research + plan (`18d3b61`):** the 64K-context minimum hasn't changed, but Qwen3.5-9B's small KV cache makes it look like it fits in 8 GB (tight). The plan uses llama.cpp, started on demand. It's in `docs/plans/hermes-agent-local-llm.md` and nothing is built yet.

### Decisions
- llama.cpp over Ollama for attempt 2 (recommended, not yet confirmed). It sets context on the server side, and it can load a text-only GGUF smaller than Ollama's vision-bundled `qwen3.5:9b`.
- The no-focus rule also applies when those five apps are opened by hand. The user accepted this.

### Issues / surprises
- May's Hermes attempt was partly sabotaged by Ollama: its `/v1` endpoint ignores per-request `num_ctx`, so models loaded at a 4096 context whatever the config said.
- May's VRAM budget never counted the desktop's own ~1.5 GB.
- Secret-scan: clean (tree + 1850 commits of history; all 6 sops files encrypted).

### Next session
- Press Mod+G on gaming and confirm nothing jumps.
- "start the Hermes plan" when ready. The six decisions come first.

**Commits**: `c8062a6..18d3b61` (2 commits)

---

## Session: 2026-10-15 (session 130) — Natty's ~/Shared "permission denied" fixed

**Focus**: Natty couldn't open or move files in `~/Shared` on natalie-laptop.

### What changed (and why)
- **Cause:** the two `.jpg`s moved into `/srv/shared` on gaming that morning kept group `users` (setgid only applies to new files, not moved ones). The clients mount the share anonymously (`sec=none`), which only gets group perms. So `users`-group files were unreadable and `644` `shared`-group files were read-only.
- **Fix:** existing files regrouped to `shared` + `g+rw` by hand; `"force user" = "bosko"` added to the Samba share (`5756d62`) so group/mode no longer matter for network access. Live on gaming, verified from natalie-laptop with a fresh `bosko:users 644` test file.

### Decisions
- `force user` over a `systemd.path` chgrp watcher (top-level-only trigger) or per-user Samba logins (bigger change, doesn't fix this bug alone). Natty's ownership was never at stake: her uploads were already `nobody`-owned.

### Issues / surprises
- `smbclient -N` on gaming read the "broken" files fine. It logs in as guest, not anonymous like the kernel mount, so it isn't a fair test of what clients see.
- The same switch (gen 441) brought `79607cc`'s global-skill fixes live on gaming.
- Secret-scan: clean (tree + 1847 commits of history; all 6 sops files encrypted).

### Next session
- Have Natty confirm she can move the `.jpg`s off the share.
- `/fleet-rollout` for laptop + natalie-laptop + vpn-server (carry-over).

**Commits**: `5756d62` (1 commit)

---

## Session: 2026-10-13 (session 129) — skill-audit fixes applied across 70+ skill files

**Focus**: Apply every finding from the 2026-10-13 `/improve-system` skill audit (17 correctness bugs + structural fixes), which the user approved in full via the boss session.

### What changed (and why)
- **Project-local skills (`27eb91f`):** correctness fixes across ~25 skills. For example, new-module's verify step now branches to `de-smoke-check` for DE modules, and ssh-host hands `!` commands off instead of running them. Hosts and aliases are now read from `hosts.json` (new per-host `aliases` field) instead of being repeated in each skill.
- **Global skills (`79607cc`):** create-loop fence bug fixed and a lint check added for it. Two new shared files, `lib/script-paths.md` and `lib/scope-since-last-run.sh`, replace per-skill copies. New helper scripts for land-prs (`merge-step.sh`) and send-results (`wrap-html.sh`).
- Long incident write-ups moved out of SKILL.md bodies into `references/`, and output templates into `assets/`, so SKILL.md files load lighter.

### Decisions
- Split the work across 10 parallel sub-agents by skill group. Six were cut off by the usage limit and resumed from where they stopped, not restarted.
- Skipped the 4-host deep-eval: no Nix code reads the new `aliases` field, and the dry-run diff was flake source only.
- Six problems found outside the audit were logged in `project-state.md`, not fixed (`classify-shared-file.sh` misses transitive imports; `diff-generations.sh` compares the wrong generation after `nh os boot`; stale `desktop-apps.nix` mentions; add-package's HM path; `vpn.nix` hardcoded endpoint; land-prs merge path never run live).

### Issues / surprises
- Several audit findings cited the wrong line or file. Each was fixed where the text actually was.
- Last session's close said `13e4616` wasn't live. gaming was switched to gen 439 at 23:46 that night, after the close, so it is live now.
- Secret-scan: clean (tree + 1845 commits of history; all 6 sops files encrypted).

### Next session
- gaming: `rebuild-switch` to bring `79607cc` live. Let it idle 10 min once to prove the DMS lock.
- `/fleet-rollout` for laptop, natalie-laptop and vpn-server.

**Commits**: `27eb91f..79607cc` (2 commits)

---

## Session: 2026-10-12 (session 128) — lock-crash fix, CI runner, boss-session wiring, DMS idle lock

**Focus**: Close out the evening's 7 commits, made across 5 separate NixOS sessions (several relayed by the new boss session). This close-out session made no code changes itself.

### What changed (and why)
- **Quickshell crash (`fbb1038`):** swaylock and DMS's lock screen fought over the session lock. DMS's retries hit an NVIDIA GL failure and quickshell aborted. DMS is now the only locker.
- **DMS idle lock (`13e4616`):** swayidle is gone. DMS's own idle timer is seeded to 10 min only when unset, and Hyprland's timeout went from 5 to 10 min to match.
- **blueprint-smith runner (`3f3cf9e`):** a self-hosted GitHub Actions runner on gaming for the Factorio harness job, because factorio.com blocks GitHub-hosted runners. It runs sandboxed, and the PAT is in sops.
- **`sops` on PATH (`333e4b4`)** on every host, so editing secrets no longer needs `nix shell`.
- **Boss session (`0e3eaca`, `c7a8c2a`, `36b49d4`):**
  - kitty windows no longer steal focus in niri.
  - kitty remote control and a tab bar now come from a drop-in that only bosko gets.
  - Claude Code gets a guarded `boss-hook` on 8 events, plus a status line.

### Decisions
- Runner jobs run as a DynamicUser with `/home` hidden, not as bosko. The repo is public and a fork PR can edit the workflow's fork guard.
- swaylock stays installed only as a TTY recovery tool. Never run it while DMS is up.

### Issues / surprises
- `classify-shared-file.sh` calls `dms-shell.nix` LOCAL even though niri.nix and hyprland.nix import it, so the 4-host sweep was run by hand.
- The `boss-hook` permission and question hooks run an unmanaged script, which must never auto-approve anything.
- Secret-scan: see the close commit.

### Next session
- gaming: `rebuild-switch` for `13e4616`, then check that DMS shows a 10-min auto-lock and swayidle is gone.
- `/fleet-rollout` for laptop, natalie-laptop and vpn-server.

**Commits**: `fbb1038..13e4616` (7 commits); gaming is on gen 438 with all but `13e4616`

---

