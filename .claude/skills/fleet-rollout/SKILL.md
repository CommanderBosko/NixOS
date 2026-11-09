---
name: fleet-rollout
description: Deploy a config change across all NixOS hosts one at a time — dry-run gate, stage for next boot (or switch live on request), reboot, full health sweep — advancing only when each host is green. Self-orchestrating loop. Use when the user says "/fleet-rollout", "run fleet-rollout", "roll out across the fleet", or "stage this change to all hosts".
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
> ⚠️ **This loop changes configuration on live machines.** In the default **boot** mode nothing
> is activated until a host reboots (which you do by hand); in **switch** mode the config is
> activated live immediately. Because it mutates running systems, ON is strongly recommended.
> Only run OFF when you've already vetted the change and accept unattended staging across
> the whole fleet.
>
> **Step 5 (and the reboot step 5b) always pause for the user on every host, regardless of
> Training Mode** — budget for those pauses even on unattended/`/loop`-scheduled runs (why:
> see Gotchas).

## Arguments

All optional, parsed from the user's phrasing:

- **Host subset** — roll out to only the named hosts (default: every host in `.flakeHosts`).
- **Order** — a custom host order (default: see Host order below).
- **Activation mode** — `boot` (default) or `switch`. Use `switch` only when the user asks
  for it ("switch", "live", "no reboot"):
  - **boot** — stage the new generation for next boot (`nh os boot` / `nixos-rebuild boot`),
    then the host is rebooted and swept. Safe for kernel/initrd/display-manager/driver
    changes, which a live `switch` can't fully apply anyway.
  - **switch** — activate live (`nh os switch` / `nixos-rebuild switch`), then sweep. No reboot
    unless the sweep reports `reboot=YES`.
- The change being rolled out is whatever is **committed** in `/home/bosko/NixOS` — there is no
  change-description argument; Step 2 requires a clean tree.

State the mode in force at the start of the run and in every hand-off message.

## Goal

Roll out the current committed config in `/home/bosko/NixOS` to every flake host (`.flakeHosts`
in `.claude/hosts.json`) one host at a time, gating each on a clean dry-run gate and a full
post-activation health sweep, so a bad change is caught on one host before it reaches the next.

## Overall done-rule

**boot mode:** every **remote** host in scope has been rebooted into the **new generation**
(`staged=no`, `reboot=no`) with **zero failed systemd units**; the **local** host has the new
generation **staged** for next boot (`staged=YES`, profile toplevel matches the Step 4
dry-run's `>>>` path) and currently has zero failed units. The local host's own reboot is the
user's follow-up and is recorded as pending in the Memory file.

**switch mode:** every host in scope is on the **new generation** (matching the current flake),
reports **zero failed systemd units**, and has **no reboot-pending kernel/initrd mismatch**.

If any host fails, the run is blocked at that host and the rest are NOT touched.

## Host order

The host set is `.flakeHosts` in `/home/bosko/NixOS/.claude/hosts.json` (the single source of truth; resolve each host's SSH target from `.hosts.<name>.ssh`). Order hosts by risk/blast-radius for the specific change being rolled out — the host least central to day-to-day use goes first, so a bad change is caught before it reaches the machine that is hardest to recover. Absent a reason to do otherwise, default to the `.flakeHosts` order with desktop hosts (`desktop: true` — list them with `jq -r '.hosts|to_entries[]|select(.value.desktop)|.key' /home/bosko/NixOS/.claude/hosts.json`) first and any headless hosts (`desktop: false`) last.

If this rollout's change is scoped to (or riskiest for) one particular host — e.g. a module only `gaming` imports, or a GPU-driver change that only applies to one host — put that host first instead, so you get the most relevant signal fastest. State the reordering and why in the report.

**Boot mode overrides this for the local host: it always goes LAST**, because rebooting it ends
the Claude session running this loop — everything else must be finished and swept first. (If
the local host is the only host in scope, that's moot.) State this in the report.

The host this loop runs on is the **local** host — deploy it with `nh os boot` (boot mode) or
`nh os switch` (switch mode). All other hosts are **remote** — deploy over SSH with
`nixos-rebuild boot|switch --target-host`. Steps 5/5b hand every host's deploy and reboot off
to the user (none has passwordless sudo). Resolve which is local with `hostname` at run start.

## Steps

For each step: read its done-rule FIRST. In Training Mode ON, if the done-rule already
passes, skip the step and tell me. Otherwise run it; if it fails, retry up to the cap,
then stop and report which step blocked. **Do not advance to the next host until the
current host passes its health sweep.**

1. **Load carry-forward memory** — read the most recent `memory-*.md` in
   `.claude/loops/fleet-rollout/` and apply its "Remember next run" notes (e.g. a host
   to skip, a known-flaky service, a value to reuse, a **pending local reboot** from the
   last boot-mode run — if one is listed, run `fleet-status` first to see whether it has
   since happened).
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
   - Local host: invoke `nixos-dry-run` (`nh os boot /home/bosko/NixOS --dry`) and **record
     the `>>>` store path** it prints (Step 6 matches the local host's staged generation
     against it).
   - Remote host: **build-as-gate** — `nixos-rebuild dry-activate` can't be used remotely
     because `switch-to-configuration` needs root on the target and polkit denies it for
     `bosko` (see Gotchas). Instead, from a scratch directory (so the `result` symlink
     doesn't land in the repo):
     `nixos-rebuild build --flake /home/bosko/NixOS#<host>`, then
     `nix copy --to ssh://<ssh-target> "$(readlink -f result)"`, then delete `result`.
     `<ssh-target>` is `$(source /home/bosko/NixOS/.claude/lib/hosts.sh && hosts_ssh <host>)`
     (e.g. `bosko@laptop`, not the bare host name). Copying the closure first also makes
     Step 5 fast. A cold build (new kernel/initrd) can exceed the 10-minute tool timeout —
     run it in the background and wait for the completion notification instead of polling.
   - Done-rule: dry-run / build + copy completes with no errors. If it errors, stop at this
     host — do NOT stage or switch.

5. **Per host — STAGE (boot mode) or SWITCH (switch mode).** Only after step 4 is green for
   this host. **Never run a desktop host's deploy via Bash** (`desktop: true` in
   `.claude/hosts.json`, local host included) — none has a NOPASSWD sudo rule, so it fails
   with "a terminal is required to read the password." Hand off instead, naming the mode and
   printing **exactly one** command; this pause applies even in Training Mode OFF (see
   Gotchas). Use `boot` or `switch` in the verb according to the mode in force:
   - Local host: print `nh os boot /home/bosko/NixOS` (boot mode) or
     `nh os switch /home/bosko/NixOS` (switch mode) and ask the user to run it in their own
     separate terminal. Don't suggest the `!` prefix: it gives sudo no TTY, so the password
     prompt fails. Wait for their confirmation it completed.
   - Remote desktop host: print
     `nixos-rebuild <boot|switch> --flake /home/bosko/NixOS#<host> --target-host <ssh-target> --elevate sudo --ask-elevate-password`
     and hand it off the same way. (`--elevate`/`--ask-elevate-password` are required — without
     them the remote activation step is denied; `--sudo` is the old alias.)
   - Done-rule: the user confirms the command completed and reports the new generation.

5b. **Per remote host, boot mode only — REBOOT.** After Step 5 for a remote host, ask the
   user to reboot it (e.g. `ssh -t <ssh-target> sudo systemctl reboot` in their terminal) and
   confirm when it's back up. Skip for the local host (see Step 6) and in switch mode.
   - Done-rule: the user confirms the host has rebooted and is reachable.

6. **Per host — FULL HEALTH SWEEP.** Delegate to the **`fleet-status` skill** (which runs
   `.claude/skills/fleet-status/scripts/fleet-status.sh`) rather than re-spelling the probe
   here — it already collects generation/`staged`, failed units, and reboot-pending
   for every host from `hosts.json`. Run it, then read **the row for the host just deployed**
   and check:
   - **Remote host, or any host in switch mode:** generation is the new one (higher than
     before the run), `staged` is `no` (the built generation is the running one), and
     `reboot` is `no`.
   - **Local host, boot mode:** `staged` is **`YES`** (expected — the new generation is built
     but not yet booted) and `readlink -f /nix/var/nix/profiles/system` equals the `>>>` path
     recorded in Step 4. Do not expect `staged=no` here; the run does not wait for the reboot.
   - `failed` is `none` (no failed systemd units). **Right after a reboot**, a mount or
     network unit (e.g. laptop's `srv-shared.mount`, a boot-time race against gaming's share)
     may show failed transiently — wait about a minute and re-run the sweep once (counts as a
     retry) before treating it as a failure.
   - Done-rule: all of the above pass for that host's row. If any fail, **stop the whole loop**
     at this host, record it, and surface the `rollback` skill as the remediation (do not
     auto-rollback). Advance to the next host only on full green.

7. **Repeat steps 4–6** (including 5b in boot mode) for each remaining host in order until
   every host in scope is green or one blocks.

## Verification plan

Before declaring the run done, prove the overall done-rule holds — re-confirm across all
hosts in scope (not just the last one touched):
- Each remote host's `/run/current-system` and `/nix/var/nix/profiles/system` resolve to the
  same toplevel (boot mode: after its reboot). In boot mode the local host instead has its
  profile pointing at the Step 4 `>>>` path with `/run/current-system` still the old one.
- `systemctl --failed` empty on every host (sweep via `fleet-status` or `ssh ... --failed`).
- No remote host reports `reboot=YES` or `staged=YES`.
If any check fails, the run is NOT done — record it in the Memory file and stop.

## End-of-run: write two files (ALWAYS)

Resolve `<today>` as the current date (YYYY-MM-DD). Write BOTH files into
`.claude/loops/fleet-rollout/`:

1. **Output** → `.claude/loops/fleet-rollout/output-<today>.md`
   The rollout report: a per-host table with dry-run result, stage/switch result +
   generation number, and health-sweep result; plus the overall done/blocked verdict. Fill
   `assets/output-template.md`.

2. **Memory** → `.claude/loops/fleet-rollout/memory-<today>.md`, filled from
   `assets/memory-template.md`. In boot mode, list the local host's **pending reboot** under
   "Remember next run".

   At the START of every run, read the most recent `memory-*.md` in this dir (if any)
   and apply its "Remember next run" notes before doing anything else.

## Report

Tell me: the activation mode, the Training Mode, the result, the per-host outcome (dry /
stage-or-switch+generation / sweep), which steps were skipped vs re-run, where the two files
were written, any **pending reboot** (boot mode: the local host — remind me to reboot and run
`/fleet-status`) and — if blocked — exactly which host and step failed and whether a rollback
is recommended.

## Gotchas

- **A Step 5 hand-off is the expected path, not a block** — no flake host has NOPASSWD
  sudo (the local host included), so `nh os boot|switch` / `nixos-rebuild boot|switch
  --target-host` run via the Bash tool fail with "a terminal is required to read the password"
  (same failure mode documented in the `rollback` and `nixos-gc` skills). Don't "fix" it by
  running the deploy directly or by suggesting the `!` prefix. Steps 5/5b therefore stop and
  hand the command to the user **regardless of Training Mode**, the same way the mandatory
  commit gate in `flake-update-verify` can't be skipped by OFF mode — budget for those
  pauses even on unattended/`/loop`-scheduled runs.
- **Remote activation needs root, and `dry-activate` can't be run remotely** — the target's
  `switch-to-configuration` runs via `systemd-run` as `bosko`, and polkit denies it ("Failed to
  start transient service unit: … requires interactive authentication"). Eval, build and
  closure copy all succeed first, so this looks like a late, confusing failure. Remote
  `boot`/`switch` hand-offs therefore carry `--elevate sudo --ask-elevate-password`, and the
  remote Step 4 gate is build + copy, not `dry-activate` (observed 2026-11-09).
- **Name the mode in the hand-off.** A `boot` run where `switch` was expected (or vice versa)
  leaves the host staged-but-not-running (`staged=YES`) or live-but-unrebooted. Always state the
  mode and print exactly one command; if the sweep shows `staged=YES` on a remote host, it was
  staged but not yet rebooted — that's Step 5b, not a failure.
- **Rebooting the local host ends the session** — hence local-last in boot mode, and the run
  finishing with the local host merely staged. The user reboots it on their own time.

## Files

- `assets/output-template.md` — shape of `output-<today>.md` (End-of-run).
- `assets/memory-template.md` — shape of `memory-<today>.md` (End-of-run).
