---
name: vpn-status
description: This skill should be used when the user wants to "check vpn status", "check vpn", "wireguard status", "see if vpn peers are connected", "check wireguard", or "show vpn peers". It SSHes to the Oracle Cloud WireGuard server and reports which peers are active.
version: 0.1.0
---

# VPN Status Check

Check WireGuard peer connectivity on the Oracle Cloud ARM VPN server at `150.136.232.63`. This is a safe, read-only operation.

## Instructions

1. Run `scripts/vpn-status.sh`. This SSHes to the server and runs `sudo wg show`.

2. Parse the `wg show` output. For each peer section, extract:
   - `peer:` — the peer's public key (use it to identify which host it is; see mapping below)
   - `endpoint:` — the peer's current IP and port
   - `latest handshake:` — when the last handshake occurred
   - `transfer:` — bytes received and sent

3. **Peer identity mapping** — resolve each `peer:` public key to a host name by reading
   `.claude/hosts.json` `.vpn.peers` (a `publicKey → hostname` map; source of truth, shared with
   `fleet-status`). The VPN subnet is `.vpn.subnet` (`10.10.0.0/24`): vpn-server is `10.10.0.1`,
   and peers are `10.10.0.2+`. Do **not** hardcode the roster here — it drifts. If a key isn't in
   `.vpn.peers`, list what `wg` reports verbatim and flag the unknown peer.

4. **Classify each peer's connection status**:
   - **Active** — last handshake within the last 3 minutes (180 seconds). WireGuard re-handshakes every ~2 minutes when traffic is flowing.
   - **Idle / stale** — last handshake between 3 minutes and 30 minutes ago. The tunnel exists but no recent traffic.
   - **Offline / never connected** — no handshake recorded, or last handshake more than 30 minutes ago.

5. Present a concise table, e.g.:

   ```
   Peer              Status    Last Handshake       Transfer (rx/tx)
   gaming            Active    42 seconds ago       14.2 MiB / 3.1 MiB
   laptop            Idle      8 minutes ago        2.0 MiB / 512 KiB
   natalie-laptop    Offline   2 hours ago          —
   ```

6. If the SSH connection fails (timeout or auth error), report the error clearly and suggest checking that the Oracle instance is running and the SSH key at `~/.ssh/id_ed25519` is correct.

## Script

```
scripts/vpn-status.sh
```
