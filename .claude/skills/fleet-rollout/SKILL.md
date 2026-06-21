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

Fixed, fail-fast order (desktops first so the server is last to receive a bad change):

1. `gaming`
2. `laptop`
3. `natalie-laptop`
4. `vpn-server`

The host this loop runs on is the **local** host — deploy it with `nh os switch`. All
other hosts are **remote** — deploy over SSH with `nixos-rebuild switch --target-host`
(use the `remote-rebuild` skill). Resolve which is local with `hostname` at run start.

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

5. **Per host — SWITCH (activate live).** Only after step 4 is green for this host:
   - Local host: `nh os switch /home/bosko/NixOS`.
   - Remote host: invoke the `remote-rebuild` skill
     (`nixos-rebuild switch --flake /home/bosko/NixOS#<host> --target-host <host>`).
   - Done-rule: switch completes exit 0 and reports the new generation activated.

6. **Per host — FULL HEALTH SWEEP.** Run the `fleet-status`-style checks against this one
   host (locally or over `ssh`):
   - New generation matches the current flake (`nixos-rebuild list-generations` / readlink
     of `/run/current-system`).
   - `systemctl --failed` is empty.
   - No reboot-pending: booted kernel/initrd match `/run/current-system`.
   - For `vpn-server` only: `wg show` reports a handshake < 3 min old.
   - Done-rule: all of the above pass. If any fail, **stop the whole loop** at this host,
     record it, and surface the `rollback` skill as the remediation (do not auto-rollback).
     Advance to the next host only on full green.

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
