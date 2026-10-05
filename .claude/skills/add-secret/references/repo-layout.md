# add-secret — repo layout

- **`.sops.yaml`** — recipient map. `keys:` lists age public keys (admin + one per host,
  each derived from that host's SSH ed25519 host key). `creation_rules:` say which
  recipients each file is encrypted to, matched by `path_regex`.
- **`secrets/common.yaml`** — shared secrets, encrypted to **admin + all hosts**. The key
  list changes over time (already has entries beyond the original three) — always check
  the file live (`grep -o '^[a-zA-Z0-9_-]*:' secrets/common.yaml`) rather than trusting an
  inline enumeration here, same as the per-host guidance below.
- **`secrets/desktop.yaml`** — secrets only the desktop hosts need (currently the bosko-owned
  Claude tooling secrets), encrypted to **admin + gaming, laptop, natalie-laptop** but NOT
  vpn-server. Declare these in a desktop-only module (`modules/claude-mcp.nix` is the
  example) — declaring one in a `commonModules` file would make vpn-server try to decrypt a
  file it can't read and fail activation.
- **`secrets/hosts/<host>.yaml`** — per-host secrets, encrypted to **admin + that host
  only**. Every host holds at least `wg-private-key` (its WireGuard key). Don't assume "each
  holds exactly one key" — per-host secrets live in `secrets/hosts/<host>.yaml` and the key
  list grows over time, so check the file live
  (`grep -o '^[a-zA-Z0-9_-]*:' secrets/hosts/<host>.yaml`) for the current list rather than
  trusting a hardcoded enumeration here.
- **Admin key**: `~/.config/sops/age/keys.txt` (NOT in repo). Required for all edits.
  Export it for every sops command: `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`.
- Tooling isn't installed system-wide — run sops via `nix shell nixpkgs#sops --command …`.
