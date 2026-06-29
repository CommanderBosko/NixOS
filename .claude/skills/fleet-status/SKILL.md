---
name: fleet-status
description: Triggers when the user says "fleet status", "host status", "check all hosts", "are all hosts healthy", "status of every machine", "health check", or "sweep the hosts". Runs a read-only health sweep across all four NixOS hosts and reports generation, failed units, reboot-pending, and VPN handshakes.
version: 0.1.0
---

# Fleet Status

A one-shot, read-only health sweep of every host in this flake (`gaming`, `laptop`,
`natalie-laptop`, `vpn-server`). Answers "is everything healthy right now?" in a single
call. Safe — all per-host probes are unprivileged; the only `sudo` is `wg show` on
vpn-server, which is passwordless there.

## Instructions

1. Run `scripts/fleet-status.sh`. For each host it SSHes (using the `~/.ssh/config`
   aliases; the current machine is probed locally) and collects:
   - **gen** — current system generation number (`/nix/var/nix/profiles/system`)
   - **ver** — `nixos-version`
   - **failed** — comma-list of failed systemd units (`systemctl --failed --plain`), or `none`
   - **up** — uptime (`d h m`, computed from `/proc/uptime`)
   - **staged** — `YES` if the latest built generation isn't the running one (a rebuild was
     staged, e.g. via `nh os boot`, but not yet activated/rebooted), else `no`
   - Then **WireGuard handshakes** for each client, read from vpn-server.

2. Present a clean table, then a short interpretation. Example:

   ```
   Host             Gen   Failed   Staged   Uptime      WG handshake
   gaming           834   none     no       2d 4h 1m    41s ago
   laptop           512   none     YES      0d 6h 12m   33s ago
   natalie-laptop   389   none     no       1d 2h 0m    18s ago
   vpn-server       77    none     no       29d 1h 5m   —
   ```

3. **Flag anything that needs attention**, in priority order:
   - **Failed units** → suggest the `journal` skill for that unit/host.
   - **staged YES** → a newer generation is built but not running; note that a reboot (or
     `nh os switch` for non-boot changes) will activate it.
   - **Stale/missing WG handshake** (> ~3 min, or `never`) → that client's tunnel is down;
     suggest the `vpn-status` skill or checking `wg-quick-wg0` on that host.
   - **UNREACHABLE host** → powered off or off-network; just report it, don't treat it as a
     failure of the sweep.

4. If a host is unreachable, the others still report — never let one timeout abort the rest.

## Notes

- Read-only and side-effect-free; safe to run anytime.
- Host reachability depends on the LAN (desktops) and the internet (vpn-server). Desktops
  are often powered off — `UNREACHABLE` is normal, not an error.
- The WireGuard peer→host mapping is read from `.claude/hosts.json` `.vpn.peers` (a
  `publicKey → hostname` map). If a peer is added or rekeyed, update it there — not in the
  script, which consumes `hosts.json` as the source of truth.

## Script

```
scripts/fleet-status.sh
```
