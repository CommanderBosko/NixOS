---
name: fleet-rollout
description: Deploy a config change across all four NixOS hosts one at a time — dry-run gate, switch live, full health sweep — advancing only when each host is green. Self-orchestrating loop. Use when the user says "/fleet-rollout", "run fleet-rollout", "roll out across the fleet", or "stage this change to all hosts".
---

# Fleet Rollout — Loop

> ## ⚙️ Loop Training Mode: **ON**
> Flip this toggle by changing the line above to `OFF`. It changes how the loop runs:
>
> **When ON (default):**
> - Pause at **every step** and wait for my explicit approval before continuing.
> - **Skip** any step that already passes its done-rule (don't redo finished work).
> - Only **re-run steps that fail** their done-rule.
> - Respect the retry cap below — never loop forever.
>
> **When OFF:**
> - Run **autonomously**, no pauses.
> - Still run **every done-rule check** and still respect the **retry cap**.
> - ON-mode pauses need an interactive turn; use OFF for unattended/`/loop`-scheduled runs.
>
> **Retry cap:** 3 attempts per failing step, then stop and report.
>
> ⚠️ **This loop activates configuration on live machines (`switch`).** Because it mutates
> running systems, ON is strongly recommended. Only run OFF when you've already vetted the
> change and accept unattended activation across the whole fleet.
>
> **Step 5 cannot run unattended for any host except `vpn-server`.** No NOPASSWD sudo rule
> exists on the local host or on gaming/laptop/natalie-laptop, so Claude cannot supply a
> sudo password — `nh os switch` / `nixos-rebuild switch --target-host` will just fail with
> "a terminal is required to read the password" if attempted directly. Step 5 always stops
> and hands the switch command to the user, **regardless of Training Mode**, the same way
> the mandatory commit gate in `flake-update-verify` can't be skipped by OFF mode. Budget
> for that pause even on unattended/`/loop`-scheduled runs.

## Goal

Roll out the current committed config in `/home/bosko/NixOS` to all four hosts —
`gaming`, `laptop`, `natalie-laptop`, `vpn-server` — one host at a time, gating each on a
clean dry-run and a full post-switch health sweep, so a bad change is caught on one host
before it reaches the next.

## Overall done-rule

Every host in scope is on the **new generation** (matching the current flake), reports
**zero failed systemd units**, has **no reboot-pending kernel/initrd mismatch**, and
`vpn-server` shows a **fresh WireGuard handshake** (< 3 min). If any host fails, the run
is blocked at that host and the rest are NOT touched.

## Host order

The host set is `.flakeHosts` in `/home/bosko/NixOS/.claude/hosts.json` (the single source of truth; resolve each host's SSH target from `.hosts.<name>.ssh`). The order below is the rollout policy — fixed, fail-fast, desktops first so the server is last to receive a bad change:

1. `gaming`
2. `laptop`
3. `natalie-laptop`
4. `vpn-server`

The host this loop runs on is the **local** host — deploy it with `nh os switch`. All
other hosts are **remote** — deploy over SSH with `nixos-rebuild switch --target-host`,
**except `vpn-server`**, which is deployed via the `remote-rebuild` skill's `boot` + reboot
method instead (see Step 5 and Gotchas for why `switch` is never used there). None of the
local/desktop switches can run unattended — only `vpn-server` has passwordless sudo, so
Step 5 always hands the others off to the user. Resolve which is local with `hostname` at
run start.

## Steps

For each step: read its done-rule FIRST. In Training Mode ON, if the done-rule already
passes, skip the step and tell me. Otherwise run it; if it fails, retry up to the cap,
then stop and report which step blocked. **Do not advance to the next host until the
current host passes its health sweep.**

1. **Load carry-forward memory** — read the most recent `memory-*.md` in
   `.claude/loops/fleet-rollout/` and apply its "Remember next run" notes (e.g. a host
   to skip, a known-flaky service, a value to reuse).
   - Done-rule: latest memory file read (or confirmed none exists).

2. **Pre-flight: working tree is committed** — the rollout deploys the committed flake.
   Run `git -C /home/bosko/NixOS status --porcelain`.
   - Done-rule: output is empty (clean tree). If dirty, stop and ask me to commit or
     confirm deploying uncommitted state before continuing.

3. **Pre-flight: flake evaluates** — invoke the `flake-check` skill (or
   `nh os boot /home/bosko/NixOS --dry` via the `nixos-dry-run` skill) once against the
   whole flake.
   - Done-rule: evaluation completes with no errors.

4. **Per host, in order — DRY-RUN GATE.** For the current host:
   - Local host: invoke `nixos-dry-run` (`nh os boot /home/bosko/NixOS --dry`).
   - Remote host: `nixos-rebuild dry-activate --flake /home/bosko/NixOS#<host> --target-host <host>`.
   - Done-rule: dry-run evaluates clean and prints the would-be changes with no errors.
     If it errors, stop at this host — do NOT switch.

5. **Per host — SWITCH (activate live).** Only after step 4 is green for this host.
   **`sudo` has no NOPASSWD rule on the local host or on gaming/laptop/natalie-laptop —
   do not run these directly via Bash, they will fail with "a terminal is required to
   read the password."** Hand off instead, and this pause applies even in Training Mode
   OFF:
   - Local host: print `nh os switch /home/bosko/NixOS` and ask the user to run it
     themselves (suggest the `!` prefix). Wait for their confirmation it completed.
   - Remote desktop host (gaming/laptop/natalie-laptop): print
     `nixos-rebuild switch --flake /home/bosko/NixOS#<host> --target-host <host>` and
     hand it off the same way — the same missing-NOPASSWD problem applies over SSH.
   - `vpn-server` only: this is the one host with passwordless sudo, so Claude CAN run
     this step itself — but never with `switch` (it tears down the SSH session
     mid-activation, per the `remote-rebuild` skill's Gotchas). Invoke the
     `remote-rebuild` skill instead, which deploys via `nixos-rebuild boot` + a clean
     reboot.
   - Done-rule: for handed-off hosts, the user confirms the command completed and
     reports the new generation; for `vpn-server`, `remote-rebuild` completes exit 0
     and reports the new generation activated.

6. **Per host — FULL HEALTH SWEEP.** Delegate to the **`fleet-status` skill** (which runs
   `.claude/skills/fleet-status/scripts/fleet-status.sh`) rather than re-spelling the probe
   here — it already collects generation/`staged`, failed units, and WireGuard handshakes
   for every host from `hosts.json`. Run it, then read **the row for the host just switched**
   and check:
   - New generation matches the current flake, and `staged` is `no` (the built generation is
     the running one — not staged-but-not-activated).
   - `failed` is `none` (no failed systemd units).
   - For `vpn-server` only: its WireGuard handshake is fresh (< 3 min old).
   - Done-rule: all of the above pass for that host's row. If any fail, **stop the whole loop**
     at this host, record it, and surface the `rollback` skill as the remediation (do not
     auto-rollback). Advance to the next host only on full green.

7. **Repeat steps 4–6** for each remaining host in order until all four are green or one
   blocks.

## Verification plan

Before declaring the run done, prove the overall done-rule holds — re-confirm across all
hosts in scope (not just the last one touched):
- Each host's `/run/current-system` derivation matches the current flake build.
- `systemctl --failed` empty on every host (sweep via `fleet-status` or `ssh ... --failed`).
- No host reports reboot-pending.
- `vpn-server` WireGuard handshake is fresh.
If any check fails, the run is NOT done — record it in the Memory file and stop.

## End-of-run: write two files (ALWAYS)

Resolve `<today>` as the current date (YYYY-MM-DD). Write BOTH files into
`.claude/loops/fleet-rollout/`:

1. **Output** → `.claude/loops/fleet-rollout/output-<today>.md`
   The rollout report: a per-host table with dry-run result, switch result + generation
   number, and health-sweep result; plus the overall done/blocked verdict.

2. **Memory** → `.claude/loops/fleet-rollout/memory-<today>.md`, with this shape:
   ```
   # fleet-rollout run — <today>

   - Mode: ON | OFF
   - Result: done | blocked at host <name>, step <n>
   - Steps skipped (already passed): <list>
   - Steps re-run: <list, with attempt counts>

   ## What worked
   - …

   ## What failed
   - …

   ## Remember next run
   - … (carry-forward notes: a host that was already up-to-date, a flaky service to
     expect, a generation number, whether a rollback was issued)
   ```

   At the START of every run, read the most recent `memory-*.md` in this dir (if any)
   and apply its "Remember next run" notes before doing anything else.

## Report

Tell me: the mode, the result, the per-host outcome (dry / switch+generation / sweep),
which steps were skipped vs re-run, where the two files were written, and — if blocked —
exactly which host and step failed and whether a rollback is recommended.

## Gotchas

- **`sudo` has no NOPASSWD rule on the local host or on gaming/laptop/natalie-laptop.**
  Running `nh os switch` or `nixos-rebuild switch --target-host <host>` directly via the
  Bash tool will fail with "a terminal is required to read the password" (same failure
  mode documented in the `rollback` and `nixos-gc` skills). Step 5 hands these off to the
  user instead of attempting them — don't "fix" that by trying to run them directly, and
  don't treat a hand-off as the step being blocked; it's the expected path.
- **`vpn-server` is the one host with passwordless sudo, but still can't use `switch`
  over SSH.** `switch-to-configuration` restarts networking, which drops the SSH session
  mid-activation and leaves firewall/NAT state inconsistent (symptom: `MASQUERADE`
  present but FORWARD/conntrack at zero). Always deploy vpn-server via the
  `remote-rebuild` skill's `boot` + reboot method, never
  `nixos-rebuild switch --target-host vpn-server` directly.
