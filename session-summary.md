# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

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

