---
name: fleet-status
description: Triggers when the user says "fleet status", "host status", "check all hosts", "are all hosts healthy", "status of every machine", "health check", or "sweep the hosts". Runs a read-only health sweep across every flakeHost in .claude/hosts.json and reports generation, failed units, staged generations, and reboot-pending.
model: haiku
version: 0.2.0
---

# Fleet Status

A one-shot, read-only health sweep of every flakeHost in `.claude/hosts.json`
(`.flakeHosts`). Answers "is everything healthy right now?" in a single call. Safe — all per-host probes are unprivileged; no `sudo` is used.

## Arguments

None — this skill takes no user-supplied arguments.

## Instructions

1. Run `.claude/skills/fleet-status/scripts/fleet-status.sh` (repo-root-relative — a bare `scripts/...` path 404s from the actual Bash-tool cwd). For each host it SSHes (using the `~/.ssh/config`
   aliases; the current machine is probed locally) and collects:
   - **gen** — current system generation number (`/nix/var/nix/profiles/system`)
   - **ver** — `nixos-version`
   - **failed** — comma-list of failed systemd units (`systemctl --failed --plain`), or `none`
   - **up** — uptime (`d h m`, computed from `/proc/uptime`)
   - **staged** — `YES` if the latest built generation isn't the running one (a rebuild was
     staged, e.g. via `nh os boot`, but not yet activated/rebooted), else `no`
   - **reboot** — `YES` if `/run/booted-system`'s kernel or initrd differs from
     `/run/current-system`'s (a switch changed them; only a reboot activates them), else `no`

2. Present a clean table, then a short interpretation. Example:

   ```
   Host             Gen   Failed   Staged   Reboot   Uptime
   gaming           834   none     no       no       2d 4h 1m
   laptop           512   none     YES      no       0d 6h 12m
   natalie-laptop   389   none     no       YES      1d 2h 0m
   ```

3. **Flag anything that needs attention**, in priority order:
   - **Failed units** → suggest the `journal` skill for that unit/host.
   - **staged YES** → a newer generation is built but not running; note that a reboot (or
     `nh os switch` for non-boot changes) will activate it.
   - **reboot YES** → the host is running a kernel/initrd it didn't boot with; a reboot is
     needed for those to take effect.
   - **UNREACHABLE host** → powered off or off-network; just report it, don't treat it as a
     failure of the sweep.

4. If a host is unreachable, the others still report — never let one timeout abort the rest.

## Notes

- Read-only and side-effect-free; safe to run anytime.
- Host reachability depends on the LAN (`local: true` hosts in `.claude/hosts.json`).
  Desktops are often powered off — `UNREACHABLE` is normal, not an error.
- The host list and SSH targets come from `.claude/hosts.json` (`.flakeHosts`, `.hosts.<name>.ssh`).
  If a host is added or dropped, update it there — not in the script, which consumes
  `hosts.json` as the source of truth.

## Script

```
.claude/skills/fleet-status/scripts/fleet-status.sh
```
