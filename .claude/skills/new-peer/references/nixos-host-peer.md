# New Peer — NixOS host branch (Step 4)

Load this in Step 4 when the new device is a NixOS flake host. It joins the tunnel through
`modules/vpn.nix`, not a raw client config, so skip `render-client-conf.sh` — Steps 3, 5 and 6
(server-side peer block, the edit, commit/deploy/verify) still apply.

Tell the user to add a `vpnIp` entry for it (the address from Step 2) to `.claude/hosts.json` —
`modules/vpn.nix` derives the host's `wg0` address from that entry, so no per-host address line
is needed — and to add the host's WireGuard public key under `.vpn.peers` there too
(`"<publicKey>": "<hostname>"`; fleet-status's `hosts_vpn_peer_name` reads it, so without this
the host shows as a raw key in the handshake table) — and, if `modules/vpn.nix` is still
commented out of `desktopModules` in `flake.nix` (as it is while vpn-server is down), to
re-enable it there.

They also need to wire their WireGuard private key through **sops-nix**, the same way every
existing host does — `modules/vpn.nix` sets
`privateKeyFile = config.sops.secrets."wg-private-key".path`, sourced from
`secrets/hosts/<host>.yaml`. So: encrypt the new host's wg private key into
`secrets/hosts/<host>.yaml` (use the `/add-secret` skill), register the host as a sops
recipient, and let the module read it. Do **not** drop a plaintext key at
`/etc/wireguard/private.key` — that path is not what the module reads and will leave the
tunnel down. (This mirrors `/new-host` Step 8.)
