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
> **Step 5 always pauses for the user on every host except `vpn-server`, regardless of
> Training Mode** — budget for that pause even on unattended/`/loop`-scheduled runs (why:
> `references/vpn-server-switch.md`).

## Arguments

All optional, parsed from the user's phrasing:

- **Host subset** — roll out to only the named hosts (default: every host in `.flakeHosts`).
- **Order** — a custom host order (default: see Host order below).
- The change being rolled out is whatever is **committed** in `/home/bosko/NixOS` — there is no
  change-description argument; Step 2 requires a clean tree.

## Goal

Roll out the current committed config in `/home/bosko/NixOS` to every flake host (`.flakeHosts`
in `.claude/hosts.json`) one host at a time, gating each on a
clean dry-run and a full post-switch health sweep, so a bad change is caught on one host
before it reaches the next.

## Overall done-rule

Every host in scope is on the **new generation** (matching the current flake), reports
**zero failed systemd units**, has **no reboot-pending kernel/initrd mismatch**, and
`vpn-server` shows a **fresh WireGuard handshake** (< 3 min). If any host fails, the run
is blocked at that host and the rest are NOT touched.

## Host order

The host set is `.flakeHosts` in `/home/bosko/NixOS/.claude/hosts.json` (the single source of truth; resolve each host's SSH target from `.hosts.<name>.ssh`). Order hosts by risk/blast-radius for the specific change being rolled out — the host least central to shared infrastructure goes first, so a bad change is caught before it reaches something harder to recover (like the VPN server). Absent a reason to do otherwise, default to the `.flakeHosts` order with desktop hosts (`desktop: true` — list them with `jq -r '.hosts|to_entries[]|select(.value.desktop)|.key' /home/bosko/NixOS/.claude/hosts.json`) first and headless hosts (`desktop: false`, e.g. `vpn-server`) last.

If this rollout's change is scoped to (or riskiest for) one particular host — e.g. a module only `vpn-server` imports, or a desktop-environment/GPU change that's meaningless on the headless server — put that host first instead, so you get the most relevant signal fastest. State the reordering and why in the report.

The host this loop runs on is the **local** host — deploy it with `nh os switch`. All
other hosts are **remote** — deploy over SSH with `nixos-rebuild switch --target-host`,
**except `vpn-server`**, which is deployed via the `remote-rebuild` skill's `boot` + reboot
method instead (Step 5). Only `vpn-server` can be deployed unattended; Step 5 hands every
desktop host off to the user. Resolve which is local with `hostname` at run start.

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
   - Done-rule: output is empty (clean tree). If dirty, stop and use the **AskUserQuestion**
     tool with options **Commit first** (hand off to `/git-commit`, then resume) and
     **Deploy uncommitted state anyway** — don't ask in free prose.

3. **Pre-flight: flake evaluates** — invoke the `flake-check` skill (or
   `nh os boot /home/bosko/NixOS --dry` via the `nixos-dry-run` skill) once against the
   whole flake, then invoke the `deep-eval-check` skill to deep-evaluate every host's full
   build graph — a shallow `flake-check` pass alone is not sufficient guarantee before a
   live rollout to every flake host (`deep-eval-check`'s own SKILL.md names itself as a
   required pre-step here).
   - Done-rule: evaluation completes with no errors AND `deep-eval-check` reports PASS for
     every host.

4. **Per host, in order — DRY-RUN GATE.** For the current host:
   - Local host: invoke `nixos-dry-run` (`nh os boot /home/bosko/NixOS --dry`).
   - Remote host: `nixos-rebuild dry-activate --flake /home/bosko/NixOS#<host> --target-host <ssh-target>`,
     where `<ssh-target>` is `$(source /home/bosko/NixOS/.claude/lib/hosts.sh && hosts_ssh <host>)`
     (e.g. vpn-server's target is `bosko@<ip>`, not the bare host name).
   - Done-rule: dry-run evaluates clean and prints the would-be changes with no errors.
     If it errors, stop at this host — do NOT switch.

5. **Per host — SWITCH (activate live).** Only after step 4 is green for this host.
   **Never run a desktop host's switch via Bash** (`desktop: true` in `.claude/hosts.json`,
   local host included) — none has a NOPASSWD sudo rule, so it fails with "a terminal is
   required to read the password." Hand off instead; this pause applies even in Training
   Mode OFF (background: `references/vpn-server-switch.md`):
   - Local host: print `nh os switch /home/bosko/NixOS` and ask the user to run it
     themselves (suggest the `!` prefix). Wait for their confirmation it completed.
   - Remote desktop host: print
     `nixos-rebuild switch --flake /home/bosko/NixOS#<host> --target-host <ssh-target>` and
     hand it off the same way.
   - `vpn-server` only: Claude CAN run this step itself (passwordless sudo), but never
     with `switch` — invoke the `remote-rebuild` skill, which deploys via
     `nixos-rebuild boot` + a clean reboot.
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

7. **Repeat steps 4–6** for each remaining host in order until every host in scope is green
   or one blocks.

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
   number, and health-sweep result; plus the overall done/blocked verdict. Fill
   `assets/output-template.md`.

2. **Memory** → `.claude/loops/fleet-rollout/memory-<today>.md`, filled from
   `assets/memory-template.md`.

   At the START of every run, read the most recent `memory-*.md` in this dir (if any)
   and apply its "Remember next run" notes before doing anything else.

## Report

Tell me: the mode, the result, the per-host outcome (dry / switch+generation / sweep),
which steps were skipped vs re-run, where the two files were written, and — if blocked —
exactly which host and step failed and whether a rollback is recommended.

## Gotchas

- **A Step 5 hand-off is the expected path, not a block** — no desktop host has NOPASSWD
  sudo; don't "fix" it by running the switch directly via Bash.
- **Never `nixos-rebuild switch --target-host vpn-server`** — always the `remote-rebuild`
  skill's `boot` + reboot (`switch` drops SSH mid-activation and leaves NAT half-applied).

Read `references/vpn-server-switch.md` for the full why behind both before working around
either.

## Files

- `assets/output-template.md` — shape of `output-<today>.md` (End-of-run).
- `assets/memory-template.md` — shape of `memory-<today>.md` (End-of-run).
- `references/vpn-server-switch.md` — NOPASSWD hand-off and vpn-server `switch` background
  (Step 5, Gotchas).
