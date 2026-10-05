# Step 8 — Register the host with sops-nix (REQUIRED)

Load this once the new host boots for the first time and `/etc/ssh/ssh_host_ed25519_key` exists — this is a post-first-boot step, not part of the initial scaffolding.

`commonModules` includes `modules/sops.nix`, which declares the shared login-password secrets (`bosko`/`natty`) with `neededForUsers = true`. **A host can only decrypt those secrets once its age identity is a recipient of `secrets/common.yaml`.** The age identity is derived from the host's SSH ed25519 host key, which only exists after the machine has booted NixOS for the first time. So this step is post-first-boot, like the hardware-config step.

> **Bootstrapping note:** on the very first build the new host is not yet a recipient, so the password hashes won't decrypt — the user accounts come up with no valid password. **Key-based SSH still works** (the install places authorized keys), so the host is reachable and recoverable. Complete this step and rebuild, and password login starts working. Don't be alarmed by sops decrypt failures in the first activation log.

Once the machine has booted and `/etc/ssh/ssh_host_ed25519_key` exists:

1. **Derive the host's age recipient key** (public; safe) using the shared helper:

   ```bash
   /home/bosko/NixOS/.claude/skills/new-host/scripts/derive-age-key.sh <hostname>
   ```

2. **Add it to `.sops.yaml`** — a new anchor under `keys:` and add the alias to the `secrets/common.yaml` creation rule's `age:` list. **A desktop host must also be added to the `secrets/desktop\.yaml$` rule** (since the 2026-09-21 split, `modules/claude-mcp.nix` declares `tailscale-mcp-env` and `discord-webhook-url` from `secrets/desktop.yaml`, and it ships in `desktopModules` — a desktop host that isn't a recipient fails to decrypt them). Headless hosts (server/remote) go in `common.yaml` only:

   ```yaml
   keys:
     # ... existing ...
     - &<hostname> age1...                    # the key from step 1
   creation_rules:
     - path_regex: secrets/common\.yaml$
       key_groups:
         - age:
             # ... existing ...
             - *<hostname>
     - path_regex: secrets/desktop\.yaml$     # desktop hosts only
       key_groups:
         - age:
             # ... existing ...
             - *<hostname>
   ```

3. **Re-encrypt** so the new recipient is included (admin key required) — `desktop.yaml` too for a desktop host:

   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     nix shell nixpkgs#sops --command sops updatekeys /home/bosko/NixOS/secrets/common.yaml
   # desktop hosts also:
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     nix shell nixpkgs#sops --command sops updatekeys /home/bosko/NixOS/secrets/desktop.yaml
   ```

4. `git add .sops.yaml secrets/common.yaml` (plus `secrets/desktop.yaml` for a desktop host), then rebuild the host. Password login now works.

If the host will also **join the VPN** (imports `vpn.nix`), it additionally needs its WireGuard private key encrypted in `secrets/hosts/<hostname>.yaml` (encrypted to admin + this host). Add a matching `creation_rule` in `.sops.yaml` and use the **`add-secret`** skill (or follow the `new-peer` flow) — `vpn.nix` reads `config.sops.secrets."wg-private-key".path`.
