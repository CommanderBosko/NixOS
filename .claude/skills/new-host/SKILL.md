---
name: new-host
description: Use this skill when the user wants to "add a new host", "scaffold a new machine", "add a new NixOS system", "create a new host", or "add X to the flake". It scaffolds all host files, registers the host with sops-nix, and shows the flake.nix entry to add.
version: 0.3.0
---

# New NixOS Host Scaffolder

Interactively gather the information needed, then write all the correctly-structured host files into the right location in this repo. The file contents come from byte-exact templates under this skill's `assets/` directory — read and fill them rather than reproducing Nix from memory. Follow all conventions exactly as described below — do not deviate from them.

## Step 1 — Gather information

Ask the user the following questions. Batch them into a single message. Do not proceed to Step 2 until you have answers to all required questions.

**Required:**

1. **Hostname** — A short, lowercase, hyphenated name (e.g. `work-laptop`, `homelab`). This becomes the flake attr key, the directory name under `hosts/`, and the value of `networking.hostName`.

2. **Host type** — One of:
   - `desktop` — Uses `desktopModules`. Has a display manager, a DE, flatpaks, Home Manager. Follows the gaming/laptop/natalie-laptop pattern.
   - `server` — Headless, uses `commonModules` only. No DE, no flatpaks, no Home Manager. Follows the server pattern.
   - `remote` — Headless, uses `commonModules`, may be a different architecture (e.g. ARM). Uses a single `configuration.nix` rather than separate `environment.nix` + `networking.nix`. Follows the vpn-server pattern.

3. **Architecture** — `x86_64-linux` (default for desktop/server) or `aarch64-linux` (typical for remote ARM). Ask only if relevant; default to `x86_64-linux` for desktop and server types, and ask explicitly for remote type.

4. **Desktop environment** — Only if type is `desktop`. Which DE module to import. Enumerate the available modules **live** (don't trust a hardcoded list — it drifts): `ls dotfiles/common/modules/desktop-environments/*.nix | xargs -n1 basename | sed 's/.nix$//'`. Ask which one to use.

5. **GPU** — Only if type is `desktop`. One of: `nvidia` (import `nvidia.nix`), `amd` (import `amd.nix`), `both` (import both), or `none`. Most machines use one or none.

6. **State version** — Default `25.11`. Only ask if the user wants to override it.

## Step 2 — Determine file paths

Based on host type:

- `desktop` → create three files:
  - `/home/bosko/NixOS/hosts/<hostname>/hardware-configuration.nix`
  - `/home/bosko/NixOS/hosts/<hostname>/environment.nix`
  - `/home/bosko/NixOS/hosts/<hostname>/networking.nix`

- `server` → create three files:
  - `/home/bosko/NixOS/hosts/<hostname>/hardware-configuration.nix`
  - `/home/bosko/NixOS/hosts/<hostname>/environment.nix`
  - `/home/bosko/NixOS/hosts/<hostname>/networking.nix`

- `remote` → create two files:
  - `/home/bosko/NixOS/hosts/<hostname>/hardware-configuration.nix`
  - `/home/bosko/NixOS/hosts/<hostname>/configuration.nix`

## Step 3 — Generate the files from the asset templates

Read the byte-exact templates from this skill's `assets/` directory and fill the placeholders — do **not** reproduce the Nix from memory. Pick the set matching the host type:

| Host type | Write these files | From these asset templates |
|-----------|-------------------|----------------------------|
| desktop   | `hardware-configuration.nix`, `environment.nix`, `networking.nix` | `assets/hardware-configuration.nix`, `assets/desktop/environment.nix`, `assets/desktop/networking.nix` |
| server    | `hardware-configuration.nix`, `environment.nix`, `networking.nix` | `assets/hardware-configuration.nix`, `assets/server/environment.nix`, `assets/server/networking.nix` |
| remote    | `hardware-configuration.nix`, `configuration.nix` | `assets/hardware-configuration.nix`, `assets/remote/configuration.nix` |

Substitutions when filling a template:
- Replace every `<hostname>` with the actual hostname.
- `hardware-configuration.nix` is always written **as-is** (it's a placeholder); the real file is generated on the target machine — see Step 7.

Per-type notes (preserve these — they encode real decisions):
- **desktop `environment.nix`:** keep `environment.systemPackages` minimal (add real packages later); leave `services.flatpak.packages` an empty list. Do NOT add aarch64 emulation (`boot.binfmt.emulatedSystems`) unless the user asks — that's gaming-specific. Drop the `displayManager.autoLogin` block if the user does not want auto-login.
- **desktop `networking.nix`:** do NOT add `wg-quick.interfaces.wg0.address` — that's added when the host joins the VPN. Leave a comment noting it can be added later.
- **remote `configuration.nix`:** the `boot` override block is only for **aarch64** (where the zen kernel + GRUB are unavailable). For an `x86_64` remote host, omit that whole block.

The templates follow the repo's Nix conventions exactly (see "Key conventions to preserve" below); don't restyle them.

## Step 4 — Write the files

Write every file using the Write tool. Show the user the complete content of each file before writing. Do not skip any file.

## Step 5 — Git add the new host directory

After writing all files, run:

```bash
git -C /home/bosko/NixOS add hosts/<hostname>/
```

This is mandatory. Nix flake evaluation cannot see untracked files. Remind the user of this if they ask why.

## Step 6 — Show the flake.nix entry (do NOT edit automatically)

Show the user the exact `nixosConfigurations.<hostname>` block to add to `flake.nix`. Read the matching template from `assets/` and fill it. Do NOT edit `flake.nix` automatically — show it, explain where it goes (after the last existing host entry, inside the `nixosConfigurations = {` attrset), and let the user add it or explicitly ask you to.

| Host type | Asset template |
|-----------|----------------|
| desktop   | `assets/flake-entry-desktop.nix.tmpl` |
| server    | `assets/flake-entry-server.nix.tmpl` |
| remote (aarch64) | `assets/flake-entry-remote.nix.tmpl` |

Fill placeholders:
- Replace `<hostname>` (and the `# <Hostname — …>` comment) throughout.
- **desktop:** replace `<de>` with the chosen DE module name; include/uncomment the GPU import lines per the user's Step 1 GPU answer — leave them commented if `none`, uncomment the relevant one(s) otherwise.
- **remote:** the remote template is for `aarch64-linux`. For an `x86_64` remote host, use the **server** entry instead (inherit `system`, no `specialArgs` override).

## Step 7 — Remind the user about hardware-configuration.nix

After showing the flake entry, tell the user:

> `hardware-configuration.nix` is a placeholder. After the machine boots NixOS for the first time, run:
> ```
> sudo nixos-generate-config --show-hardware-config
> ```
> Copy the output into `hosts/<hostname>/hardware-configuration.nix` and rebuild.

## Step 8 — Register the host with sops-nix (REQUIRED)

`commonModules` includes `dotfiles/common/modules/sops.nix`, which declares the shared login-password secrets (`bosko`/`natty`) with `neededForUsers = true`. **A host can only decrypt those secrets once its age identity is a recipient of `secrets/common.yaml`.** The age identity is derived from the host's SSH ed25519 host key, which only exists after the machine has booted NixOS for the first time. So this step is post-first-boot, like the hardware-config step.

> **Bootstrapping note:** on the very first build the new host is not yet a recipient, so the password hashes won't decrypt — the user accounts come up with no valid password. **Key-based SSH still works** (the install places authorized keys), so the host is reachable and recoverable. Complete this step and rebuild, and password login starts working. Don't be alarmed by sops decrypt failures in the first activation log.

Once the machine has booted and `/etc/ssh/ssh_host_ed25519_key` exists:

1. **Derive the host's age recipient key** (public; safe):

   ```bash
   ssh bosko@<hostname> 'cat /etc/ssh/ssh_host_ed25519_key.pub' \
     | nix shell nixpkgs#ssh-to-age --command ssh-to-age
   ```

2. **Add it to `.sops.yaml`** — a new anchor under `keys:` and add the alias to the `secrets/common.yaml` creation rule's `age:` list:

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
   ```

3. **Re-encrypt** so the new recipient is included (admin key required):

   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     nix shell nixpkgs#sops --command sops updatekeys /home/bosko/NixOS/secrets/common.yaml
   ```

4. `git add .sops.yaml secrets/common.yaml`, then rebuild the host. Password login now works.

If the host will also **join the VPN** (imports `vpn.nix`), it additionally needs its WireGuard private key encrypted in `secrets/hosts/<hostname>.yaml` (encrypted to admin + this host). Add a matching `creation_rule` in `.sops.yaml` and use the **`add-secret`** skill (or follow the `new-peer` flow) — `vpn.nix` reads `config.sops.secrets."wg-private-key".path`.

---

## Step 9 — Suggest a dry-run

After the user adds the flake entry (or asks you to), remind them to test with:

```
nh os boot /home/bosko/NixOS --dry
```

or the `nixos-dry-run` skill, before doing a full rebuild.

---

## Key conventions to preserve

- 2-space indentation throughout.
- Opening brace on the same line as the attribute name.
- `with pkgs;` inside list expressions, never at the top level.
- Comments use `#` with a space, written in sentence case.
- `{ ... }:` when the module uses no named arguments. `{ pkgs, ... }:` when it references `pkgs.*`. `{ lib, pkgs, ... }:` when it also calls `lib.*`.
- `lib.mkForce` is used on `boot.kernelPackages` and `boot.loader.grub.enable` in `configuration.nix` for remote hosts because `commonModules/bootloader.nix` sets those values and they must be overridden cleanly.
- `security.nix` already handles AppArmor, audit, PAM wheel, ASLR, and kexec for all hosts — do not add any of those in host files.
- `sops.nix` (in `commonModules`) supplies the shared login-password secrets to every host. A new host must be registered as a sops recipient (Step 8) or it cannot decrypt them. Do not add `sops.*` config to host files.
- `audio.nix` already handles PipeWire for desktop hosts — do not add PipeWire config.
- Do NOT add `virtualisation.nix`, `gaming.nix`, or `vpn.nix` to the new host entry unless the user explicitly asks — those are optional host-specific modules.
