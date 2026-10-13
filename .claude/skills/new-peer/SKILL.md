---
name: new-peer
description: Triggers when user says "add a VPN peer", "add a new peer", "add device to VPN", "new wireguard peer", "add phone to VPN", or "add X to wireguard". Guides the user through adding a new WireGuard peer to the VPN — editing the vpn-server configuration and generating the client config snippet for the new device.
model: haiku
version: 0.2.0
---

# New WireGuard Peer

Interactively gather the information needed, then edit `hosts/vpn-server/wireguard.nix` with the new peer block and give the user the client-side config. Follow all steps in order.

## Arguments

Parse from the user's request before asking anything:

- **device-name** — a short name/description for the peer, taken from the phrasing (e.g. "add my phone to the VPN" → `phone`). Used as the comment above the peer block. If absent, ask in Step 1.
- **public-key** — the device's WireGuard public key, if the user already pasted one. Only public keys go in the repo — never a private key. If absent, ask in Step 1 (and offer the key-generation command).

## Step 1 — Gather information

Ask the user the following questions in a single message. Do not proceed to Step 2 until you have answers.

**Required:**

1. **Device name / description** — What is this peer? (e.g. `phone`, `work-laptop`, `tablet`). Used as the comment above the peer block.

2. **Public key** — Ask via the **AskUserQuestion tool** whether the device already has a WireGuard key pair, with options `Already have a public key` and `Need to generate one`, rather than free-form prose.
   - If **Already have a public key**: ask the user to paste the public key now.
   - If **Need to generate one**: tell the user to run the following command **on the new device** and paste back only the public key:
     ```
     wg genkey | tee privatekey | wg pubkey > publickey
     ```
     Warn them: the private key must stay on the device and must **never** be shared or committed to the repo. Only the public key goes into the NixOS config.

Do not proceed until you have the public key in hand.

## Step 2 — Determine the next available IP

Run (repo-root-relative — a bare `scripts/...` path 404s from the actual Bash-tool cwd):

```bash
.claude/skills/new-peer/scripts/next-vpn-ip.sh
```

This checks both sources of truth — `.claude/hosts.json`'s `vpnIp` entries (flake hosts) and every
VPN-subnet address literally assigned in `hosts/vpn-server/wireguard.nix` (covers ad-hoc peers
— phones, non-NixOS devices — that have no `hosts.json` entry) — and prints the next unused address
as `NEXT_IP=<address>` on its first line, `SERVER_PUBKEY=<key>` on its second, and
`SERVER_ENDPOINT=<ip:port>` on its third (the key and endpoint read live from `modules/vpn.nix`
rather than hardcoded; `NEXT_IP` and `SERVER_PUBKEY` are reused in Steps 3–4). The VPN subnet is
`.vpn.subnet` in `.claude/hosts.json`; vpn-server's own `vpnIp` there is reserved for the server
itself. A non-zero exit means it couldn't find any existing address, public key, or endpoint —
investigate rather than guessing a starting point.

## Step 3 — Show the server-side peer block

Present the peer block to add to `hosts/vpn-server/wireguard.nix`. It goes inside the `peers = [ ... ];` list under `networking.wg-quick.interfaces.wg0`:

```nix
{
  # <device-name>
  publicKey = "<public-key>";
  allowedIPs = [ "<NEXT_IP>/32" ];
}
```

## Step 4 — Show the client-side WireGuard config

**If the new device is a NixOS host**, read `references/nixos-host-peer.md` and follow it instead of rendering a client config (hosts.json `vpnIp` + `.vpn.peers` entries, sops-wired private key, re-enabling `modules/vpn.nix`).

**If the new device is a phone, non-NixOS machine, or any device that cannot use the Nix module**, give them a raw `wg-quick` config file to paste into their WireGuard app. Render it (repo-root-relative, like Step 2) with the `NEXT_IP` and `SERVER_PUBKEY` values from Step 2 — re-run `next-vpn-ip.sh` first if Step 2 happened long enough ago that either might be stale:

```bash
.claude/skills/new-peer/scripts/render-client-conf.sh <NEXT_IP> <SERVER_PUBKEY>
```

It fills `assets/client.conf.tmpl`: the address with `.vpn.subnet`'s prefix length and the endpoint from `.vpn.endpoint`, both read from `.claude/hosts.json`. `AllowedIPs` is already correct in the template. A non-zero exit means a bad address/key, or that `modules/vpn.nix`'s endpoint disagrees with hosts.json — fix the stale one rather than hand-editing the output. Show the output as-is.

`<their-private-key>` stays a placeholder on purpose. Remind the user that it is the private key that stays on their device — it is never shared or stored anywhere else.

## Step 5 — Edit the vpn-server config

Make the edit to `hosts/vpn-server/wireguard.nix`. Add the new peer block at the end of the `peers` list, following the same formatting as the existing entries (2-space indented, comment line above `publicKey`).

Show the user a short diff-style summary of what was added before writing.

## Step 6 — Remind the user what comes next

Tell the user the following steps are still needed to activate the peer:

1. **Commit the change** — use `/git-commit` to stage and commit `hosts/vpn-server/wireguard.nix`.
2. **Deploy to vpn-server** — push the commit, then deploy with the `/remote-rebuild` skill (it resolves the target from `.claude/hosts.json` and uses vpn-server's correct `boot`+reboot flow). To do it by hand, resolve vpn-server's SSH target from `.claude/hosts.json` and rebuild from the repo flake.
3. **Verify the peer connected** — run `/vpn-status` after the new device activates its tunnel to confirm the handshake shows up.

---

## Key constraints

- **Never generate, display, or store private keys.** Only public keys go into the repo. If the user accidentally pastes a private key, tell them immediately and do not commit it.
- **Do not stage or commit** — that is `/git-commit`'s job.
- The server public key must always be read live from `modules/vpn.nix` (via `next-vpn-ip.sh`), and the endpoint and subnet from `.claude/hosts.json` (`.vpn.endpoint`, `.vpn.subnet`), at the time of the skill run — not assumed from this file.
- The VPN subnet is `.vpn.subnet`, not the LAN subnet the hosts' `ip` values sit on. Double-check the existing peer IPs before assigning a new one.
- This repo's working directory is always `/home/bosko/NixOS`.

## Scripts

- `scripts/next-vpn-ip.sh` — prints the next unused address in `.vpn.subnet` (`NEXT_IP=...`), the server's current public key (`SERVER_PUBKEY=...`), and its current endpoint (`SERVER_ENDPOINT=...`), all read live. Used in Step 2 (Steps 3–4 reuse `NEXT_IP`/`SERVER_PUBKEY`).
- `scripts/render-client-conf.sh <address> <server-public-key>` — renders `assets/client.conf.tmpl` for a non-NixOS device (endpoint and subnet prefix from `.claude/hosts.json`; `<their-private-key>` left as a placeholder). Used in Step 4.

## Assets

- `assets/client.conf.tmpl` — raw `wg-quick` client config for non-NixOS devices. Filled by `render-client-conf.sh` (never by hand), which leaves only `<their-private-key>` for the device. Used in Step 4.

## References

- `references/nixos-host-peer.md` — Step 4's NixOS-host branch: hosts.json entries, sops-wired private key, re-enabling `modules/vpn.nix`.
