---
name: vpn-status
description: This skill should be used when the user wants to "check vpn status", "check vpn", "wireguard status", "see if vpn peers are connected", "check wireguard", or "show vpn peers". It SSHes to the Oracle Cloud WireGuard server and reports which peers are active.
model: haiku
version: 0.1.0
---

# VPN Status Check

Check WireGuard peer connectivity on the Oracle Cloud ARM VPN server (`vpn-server` in `.claude/hosts.json`). This is a safe, read-only operation.

## Instructions

1. Run `scripts/vpn-status.sh`. It SSHes to the server, runs `sudo wg show wg0 dump`, and does the
   parsing itself: resolves each peer's public key to a host name via `.claude/hosts.json`
   `.vpn.peers` (a `publicKey → hostname` map; source of truth, shared with `fleet-status` — the
   script does **not** hardcode the roster), classifies each peer's connection status against fixed
   thresholds (**Active** ≤180s since last handshake, **Idle** 180s–1800s, **Offline** >1800s or
   never), and prints the finished table directly:

   ```
   Peer              Status    Last Handshake       Transfer (rx/tx)
   gaming            Active    42 seconds ago       14.2 MiB / 3.1 MiB
   laptop            Idle      8 minutes ago        2.0 MiB / 512 KiB
   natalie-laptop    Offline   2 hours ago          890 MiB / 210 MiB
   ```

   Present that table as-is. If a peer's resolved name looks like `unknown:<pubkey prefix>`, its
   public key isn't in `.vpn.peers` — flag it to the user as an unrecognized peer rather than
   silently showing the placeholder name.

2. If the script fails (SSH timeout or auth error), report the error clearly and suggest checking
   that the Oracle instance is running and the SSH key at `~/.ssh/id_ed25519` is correct.

## Script

```
scripts/vpn-status.sh
```
