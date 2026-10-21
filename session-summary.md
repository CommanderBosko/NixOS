# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

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

## Session: 2026-10-19 (session 134) — close-out after Proton/Hermes hardening day

**Focus**: Close-only session. Several earlier conversations the same day (not visible here) landed the work below.

### What changed (and why)
- **`130730a`:** Proton Mail Bridge + himalaya for Hermes on gaming, config as a sops template so the address stays out of the public repo; replaces Gmail after an app password leaked into Hermes memory.
- **PR #38:** Hermes memory checker blocks credential-like entries locally before calling `claude -p`.
- **PR #35/#36/#37/#39:** skill-audit fixes, CI `--no-build` removal, improve-system leftovers. `2b09612` bumps hermes-agent.

### Decisions
- No code changes this session. Secret-scan clean on tree and history.

### Next session
- Post-reboot verification (Bridge login, himalaya, Hermes checker); user revokes the Gmail app password.

**Commits**: `7443ee5..2b09612`

---

## Session: 2026-10-18 (session 133) — flake input bump

**Focus**: Bump flake inputs and prove they still evaluate (no apply).

### What changed (and why)
- **`23bda63`:** bumped dms, dank-qml-common, hermes-agent, home-manager, nixpkgs, sops-nix. flake-check + deep-eval clean on all 4 hosts. Committed and pushed but not rebuilt on any host.

### Decisions
- Lock bump left unapplied, per the `/flake-update-verify` workflow; roll out later via `/fleet-rollout`.

### Next session
- Apply the 10-18 bump (includes a hermes-agent bump, so re-check `hermes` on gaming after the rebuild).

**Commits**: `23bda63` (1 commit)

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

