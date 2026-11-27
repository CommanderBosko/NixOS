---
name: deploy-pi-host
description: Ship one committed config change to one already-migrated Raspberry Pi NixOS host (famdash, later pi-hole) - pre-build the aarch64 toplevel on gaming, hand off the single nixos-rebuild --target-host command, then verify the Pi is running exactly what was built. Use when the user says "deploy to the pi", "deploy the pi host", "update famdash", "push config to the pi", "deploy-pi-host", "rebuild the pi".
version: 0.1.0
---

# Deploy Pi Host

Update ONE already-migrated Raspberry Pi: build its system on gaming, hand the user the single `nixos-rebuild --target-host` command, then check the Pi runs exactly what was built. (Bucket: Orchestration)

**This is not:**
- a multi-host or fleet-wide rollout, reboot/cleanup loops, Training Mode or run memory files — that is `fleet-rollout` (it also owns the generic remote path this skill specialises);
- a first install — flashing the card, sops bootstrap, Tailscale identity and cutover are `pi-sd-flash` + `pi-cutover`;
- a single-unit health check (`verify-service`) or a read-only sweep of every host (`fleet-status`);
- a rollback (`rollback`), scaffolding a host (`new-host`) or editing secrets (`add-secret`).

## Arguments

Parsed from the user's phrasing:

- **`<host>`** (required) — a Pi flake host from `.claude/hosts.json` (`famdash` today, `pi-hole` once migrated) or one of its aliases. "The pi" is ambiguous once there are two: list the candidates live (`jq -r '.hosts | to_entries[] | select(.value.flakeHost and .value.arch == "aarch64-linux") | .key' /home/bosko/NixOS/.claude/hosts.json`) and ask with the **AskUserQuestion** tool.
- **mode** (optional) — `switch` (default: activates live) or `boot` (stages the generation; only a reboot activates it). Recommend `boot` when the change bumps the kernel, firmware or bootloader (a nixpkgs / `flake.lock` bump); otherwise use `switch` and say so. Ask via **AskUserQuestion** only when it is genuinely unclear.
- **`--ip IP`** (optional) — override the tailscale IP from `hosts.json`.

State the host and mode at the start and in every hand-off. In the commands below, `PD` means `/home/bosko/NixOS/.claude/skills/deploy-pi-host/scripts/pi-deploy.sh` (absolute: a bare `scripts/...` path 404s from the Bash tool's cwd).

## Steps

1. **Resolve the host.** Confirm which Pi and which mode. `PD` itself refuses (exit 1) a host that is not aarch64 or not in `.flakeHosts` — a Pi that is not migrated yet (`pi-hole` today, `flakeHost: false`) is a `pi-sd-flash` + `pi-cutover` job, not this one. The deploy ships what the flake in `/home/bosko/NixOS` evaluates to, so the change should be committed.
   - Done-rule: host and mode are named.

2. **Build on gaming.** `PD build <host>` (add `--dry-run` first if the user wants to see what would be built or fetched; it writes nothing). Only the binfmt host (gaming) can build aarch64; the laptops cannot, and never build on the Pi itself. It prints `EXPECTED <store path>`, builds, and prints `BUILT <store path>` — **record that path**. A cold build under QEMU can exceed the 10-minute tool timeout: run it with the Bash tool's `run_in_background` and wait for the completion notification instead of polling.
   - A `WARN uncommitted-changes` does not block: say so and offer **Commit first** / **Deploy anyway** via **AskUserQuestion** (nix includes tracked working-tree edits, never untracked files).
   - Exit 1 "cannot build aarch64" means this is not gaming — tell the user to run the build (and step 3) on gaming. A nix eval/build error: show the tail, stop, hand nothing off.
   - Done-rule: exit 0 with an `EXPECTED` and a `BUILT` line (dry-run: exit 0).

3. **Hand off the deploy.** `PD cmd <host> --mode <switch|boot>` prints one comment line and **exactly one** command: `nixos-rebuild <mode> --flake <repo>#<host> --target-host <user@ip> --elevate sudo --ask-elevate-password`. **Never run it via Bash** — no host has NOPASSWD sudo, so it dies with "a terminal is required to read the password". Show it verbatim, name the mode, and ask the user to run it in their own separate terminal on the machine that ran the build (no `!` prefix: that gives sudo no TTY). Wait for their confirmation. This pause applies every time.
   - Done-rule: the user confirms it completed (and reports any error — then stop and diagnose, do not re-hand-off blindly).

4. **Verify.** `PD verify <host> --mode <mode> --expect <EXPECTED path from step 2>` (read-only ssh, no sudo). Report each line as PASS / WARN / FAIL:
   - `current-system` — the Pi runs the expected toplevel (`--expect` pins what was built even if the tree changed since). FAIL = not deployed yet or a different commit. In boot mode, "staged, not running" is a WARN until the reboot.
   - `failed-units` — none. A unit that fails right after a switch may be transient: wait about a minute and re-run once before calling it FAIL; if it persists, look at it with the `journal` skill.
   - `reboot` — WARN "reboot pending (kernel/initrd changed)" is expected after a kernel bump, not a failure. `/run/booted-system` stays the old path until a reboot (printed as INFO).
   - `uptime` — INFO.
   - Done-rule: exit 0 (no FAIL), with every WARN explained to the user.
   - **On FAIL: stop and report; do not auto-rollback.** Point at the `rollback` skill's flow (generation list, confirm, hand-off) — but it is written for the local host, so for the Pi the hand-off command is `ssh -t <user@ip> sudo nixos-rebuild switch --rollback` in the user's terminal. Do not redeploy hoping it sticks.

5. **Reboot if needed.** Only for boot mode, or a `reboot pending` WARN the user wants resolved now: `PD cmd <host> --reboot` prints the single reboot hand-off (`ssh -t <user@ip> sudo systemctl reboot`). Hand it off like step 3, wait for confirmation, give the Pi a minute or two to rejoin the tailnet, then re-run step 4. If the user defers the reboot, record it as pending in the report.
   - Done-rule: re-verify is green with no reboot-pending WARN, or the user explicitly defers.

6. **Report:** host, mode, the EXPECTED store path, each verify check result, whether a reboot is pending, and on FAIL the recommended next step. For the fleet-wide view (generation numbers, other hosts) point at `fleet-status`.

## Gotchas

- **Both hand-offs are the expected path, not a block.** The deploy and the reboot each need sudo on the Pi, which has no NOPASSWD. Print one command, wait, never suggest the `!` prefix.
- **Build and hand-off both run on gaming.** `nixos-rebuild --target-host` builds on the machine that runs it; anywhere without aarch64 emulation it fails late. Never build on the Pi (1-4 GB RAM).
- **Verify against what was built.** Pass `--expect`; without it `verify` re-evaluates the flake, and a tree edited since the build reports a false mismatch.
- **Name the mode.** A `boot` deploy verified as `switch` (or the reverse) looks like a failure; `verify --mode` must match the hand-off.
- **No cleanup, no fleet loop here.** Old generations are the rollback target; the Pi's own GC timer trims them. A rollout across several hosts belongs to `fleet-rollout`.
- More (flag aliases, boot mode on a Pi, the first-boot-only root-partition fix, SSH dropping mid-switch): `references/pi-deploy-gotchas.md`.

## Scripts

- `.claude/skills/deploy-pi-host/scripts/pi-deploy.sh <build|cmd|verify> <host> [--ip IP] [--mode switch|boot] [--expect STORE_PATH] [--dry-run] [--reboot]` — step 2 (`build`, `--dry-run`), step 3 (`cmd`), step 4 (`verify`, read-only), step 5 (`cmd --reboot`). Exit 0 ok (verify: no FAIL), 1 check failed or refused, 2 usage error. Host, IP and arch come from `.claude/hosts.json` through `.claude/lib/pi-host.sh`; nothing is hardcoded per Pi.
- `.claude/skills/deploy-pi-host/scripts/pi-deploy.test.sh` — no args; runs the script against PATH shims and a fixture hosts.json (no real host is contacted). Run it after editing `pi-deploy.sh`; no step calls it.

## References

- `references/pi-deploy-gotchas.md` — why only gaming builds, the nixos-rebuild flag aliases, `boot` vs `switch` on a Pi's U-Boot/extlinux setup, why the expand-root-partition fix does not matter for day-2 deploys, cleanup, how this relates to `fleet-rollout` / `fleet-status`. Load it before the first deploy to a newly migrated Pi, or when a build, hand-off or verify result is surprising.
