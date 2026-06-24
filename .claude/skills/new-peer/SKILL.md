---
name: new-peer
description: Triggers when user says "add a VPN peer", "add a new peer", "add device to VPN", "new wireguard peer", "add phone to VPN", or "add X to wireguard". Guides the user through adding a new WireGuard peer to the VPN — editing the vpn-server configuration and generating the client config snippet for the new device.
version: 0.1.0
---

# New WireGuard Peer

Interactively gather the information needed, then edit `hosts/vpn-server/configuration.nix` with the new peer block and give the user the client-side config. Follow all steps in order.

## Step 1 — Gather information

Ask the user the following questions in a single message. Do not proceed to Step 2 until you have answers.

**Required:**

1. **Device name / description** — What is this peer? (e.g. `phone`, `work-laptop`, `tablet`). Used as the comment above the peer block.

2. **Public key** — Does the device already have a WireGuard key pair, or does it need one generated?
   - If it already has one: ask the user to paste the public key now.
   - If it needs one: tell the user to run the following command **on the new device** and paste back only the public key:
     ```
     wg genkey | tee privatekey | wg pubkey > publickey
     ```
     Warn them: the private key must stay on the device and must **never** be shared or committed to the repo. Only the public key goes into the NixOS config.

Do not proceed until you have the public key in hand.

## Step 2 — Determine the next available IP

Read `hosts/vpn-server/configuration.nix` to find the highest `allowedIPs` entry currently assigned to a peer. The VPN subnet is `10.10.0.0/24`:

- vpn-server: `10.10.0.1` (reserved)
- gaming:      `10.10.0.2`
- laptop:      `10.10.0.3`
- natalie-laptop: `10.10.0.4`

Assign the next unused address (currently `10.10.0.5`). If the file has changed since this was written, increment beyond whatever the current highest peer IP is.

## Step 3 — Show the server-side peer block

Present the peer block to add to `hosts/vpn-server/configuration.nix`. It goes inside the `peers = [ ... ];` list under `networking.wg-quick.interfaces.wg0`:

```nix
{
  # <device-name>
  publicKey = "<public-key>";
  allowedIPs = [ "10.10.0.<n>/32" ];
}
```

## Step 4 — Show the client-side WireGuard config

The server's public key (from `dotfiles/common/modules/vpn.nix`) is:

```
ijhN7KUmHx5TOLpKgyzJpzSvp49TkD0c2CTf32Cyu1U=
```

Before presenting it, verify this is still current by reading `dotfiles/common/modules/vpn.nix` and checking the `publicKey` field in the `peers` list. Use whatever value is actually in the file.

**If the new device is a NixOS host**, tell the user they can import `dotfiles/common/modules/vpn.nix` and then set the host-specific address in the host's own config:

```nix
networking.wg-quick.interfaces.wg0.address = [ "10.10.0.<n>/24" ];
```

They also need to place their private key at `/etc/wireguard/private.key` on the new host (not in the repo).

**If the new device is a phone, non-NixOS machine, or any device that cannot use the Nix module**, give them a raw `wg-quick` config file to paste into their WireGuard app:

```ini
[Interface]
PrivateKey = <their-private-key>
Address = 10.10.0.<n>/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ijhN7KUmHx5TOLpKgyzJpzSvp49TkD0c2CTf32Cyu1U=
Endpoint = 150.136.232.63:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

Remind the user that `<their-private-key>` is the private key that stays on their device — it is never shared or stored anywhere else.

## Step 5 — Edit the vpn-server config

Make the edit to `hosts/vpn-server/configuration.nix`. Add the new peer block at the end of the `peers` list, following the same formatting as the existing entries (2-space indented, comment line above `publicKey`).

Show the user a short diff-style summary of what was added before writing.

## Step 6 — Remind the user what comes next

Tell the user the following steps are still needed to activate the peer:

1. **Commit the change** — use `/commit` to stage and commit `hosts/vpn-server/configuration.nix`.
2. **Deploy to vpn-server** — push the commit, then deploy with the `/remote-rebuild` skill (it targets `bosko@150.136.232.63` and uses vpn-server's correct `boot`+reboot flow). To do it by hand, `ssh bosko@150.136.232.63` and rebuild from the repo flake.
3. **Verify the peer connected** — run `/vpn-status` after the new device activates its tunnel to confirm the handshake shows up.

---

## Key constraints

- **Never generate, display, or store private keys.** Only public keys go into the repo. If the user accidentally pastes a private key, tell them immediately and do not commit it.
- **Do not stage or commit** — that is `/commit`'s job.
- The server public key must always be read from `dotfiles/common/modules/vpn.nix` at the time of the skill run, not assumed from this file.
- The VPN subnet is `10.10.0.0/24` (not `10.0.0.0/24`). Double-check the existing peer IPs before assigning a new one.
- This repo's working directory is always `/home/bosko/NixOS`.
