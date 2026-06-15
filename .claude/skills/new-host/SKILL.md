---
name: new-host
description: Use this skill when the user wants to "add a new host", "scaffold a new machine", "add a new NixOS system", "create a new host", or "add X to the flake". It scaffolds all host files, registers the host with sops-nix, and shows the flake.nix entry to add.
version: 0.2.0
---

# New NixOS Host Scaffolder

Interactively gather the information needed, then write all the correctly-structured host files into the right location in this repo. Follow all conventions exactly as described below — do not deviate from them.

## Step 1 — Gather information

Ask the user the following questions. Batch them into a single message. Do not proceed to Step 2 until you have answers to all required questions.

**Required:**

1. **Hostname** — A short, lowercase, hyphenated name (e.g. `work-laptop`, `homelab`). This becomes the flake attr key, the directory name under `hosts/`, and the value of `networking.hostName`.

2. **Host type** — One of:
   - `desktop` — Uses `desktopModules`. Has a display manager, a DE, flatpaks, Home Manager. Follows the gaming/laptop/natalie-laptop pattern.
   - `server` — Headless, uses `commonModules` only. No DE, no flatpaks, no Home Manager. Follows the server pattern.
   - `remote` — Headless, uses `commonModules`, may be a different architecture (e.g. ARM). Uses a single `configuration.nix` rather than separate `environment.nix` + `networking.nix`. Follows the vpn-server pattern.

3. **Architecture** — `x86_64-linux` (default for desktop/server) or `aarch64-linux` (typical for remote ARM). Ask only if relevant; default to `x86_64-linux` for desktop and server types, and ask explicitly for remote type.

4. **Desktop environment** — Only if type is `desktop`. Which DE module to import. Available DE modules in `dotfiles/common/modules/desktop-environments/`: `niri`, `plasma`, `cosmic`, `gnome`, `hyprland`, `kde-mobile`, `labwc`, `phosh`, `river`, `sway`, `wayfire`. Ask which one to use.

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

## Step 3 — Generate the files

Use the templates below. Fill them in precisely. Do not add unnecessary abstractions — match the style of existing hosts exactly.

---

### Template: hardware-configuration.nix (all host types)

This is always a placeholder. The real file must be generated on the target machine.

```nix
# Placeholder — replace with output of: sudo nixos-generate-config --show-hardware-config
# Run that command on <hostname> and paste the result here, then rebuild.
{ ... }:

{
  # Hardware configuration is machine-specific.
  # Generate with: sudo nixos-generate-config --show-hardware-config
}
```

---

### Template: environment.nix for desktop hosts

Mirror the gaming/laptop pattern. Use `{ pkgs, ... }:` signature (include `pkgs` since it references `pkgs.*`).

```nix
{ pkgs, ... }:

{
  # Services
  services = {
    # Display manager settings
    displayManager = {
      autoLogin = {
        enable = true;
        user = "bosko";
      };
    };

    # Enable printing
    printing.enable = true;
  };

  # Hardware
  hardware = {
    # Bluetooth settings
    bluetooth = {
      enable = true;
      powerOnBoot = false;
      settings.General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    # Enable graphical interface
    graphics.enable = true;
  };

  # System packages
  environment.systemPackages = with pkgs; [
    brave
    firefox
    kitty
  ];

  # Flatpaks
  services.flatpak.packages = [
  ];
}
```

Notes:
- Keep `environment.systemPackages` minimal; add real packages later.
- Leave `services.flatpak.packages` as an empty list — the user can populate it later.
- Do NOT include aarch64 emulation (`boot.binfmt.emulatedSystems`) unless the user specifically asks; that is gaming-specific.
- Do NOT include `displayManager.autoLogin` if the user says they do not want auto-login.

---

### Template: networking.nix for desktop hosts

Mirror the gaming/laptop pattern. Use `{ ... }:` signature (no pkgs or lib needed).

```nix
{ ... }:

{
  # Configure networking
  networking = {
    # Set host name
    hostName = "<hostname>";

    # Enable networking
    networkmanager = {
      enable = true;
      dns = "none";
    };

    # Enable custom DNS servers
    nameservers = [
      "10.0.0.20"
      "1.1.1.1"
    ];

    # Enable and open ports in the firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  # SSH settings
  services = {
    # Network clock sync
    chrony.enable = true;

    # Enable and configure openssh
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        PrintMotd = false;
        AllowUsers = [ "bosko" ];
      };
    };
  };
}
```

Note: Do NOT add `wg-quick.interfaces.wg0.address` — the user adds that when they join the VPN. Leave a comment noting it can be added when ready.

---

### Template: environment.nix for server hosts

Mirror the server pattern. Use `{ pkgs, ... }:` signature.

```nix
{ pkgs, ... }:

{
  # System
  system = {
    # Automatic updating
    autoUpgrade = {
      enable = true;
      dates = "daily";
      persistent = true;
    };
  };

  # Set max journal entries
  services.journald.extraConfig = ''
    SystemMaxUse=500M
  '';

  # Enable sudo for wheel group
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # Automatic cleanup
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  # System packages
  environment.systemPackages = with pkgs; [
    tmux
  ];
}
```

---

### Template: networking.nix for server hosts

Mirror the server pattern. Use `{ ... }:` signature.

```nix
{ ... }:

{
  # Configure networking
  networking = {
    # Set host name
    hostName = "<hostname>";

    # Use DHCP; NetworkManager is unnecessary on a headless server
    networkmanager.enable = false;
    useDHCP = true;

    # Enable custom DNS servers
    nameservers = [
      "10.0.0.20"
      "1.1.1.1"
    ];

    # Enable and open ports in the firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  # SSH settings
  services = {
    # Network clock sync
    chrony.enable = true;

    # Enable and configure openssh
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
}
```

---

### Template: configuration.nix for remote hosts

Mirror the vpn-server pattern. Use `{ pkgs, lib, ... }:` signature (both `pkgs` and `lib` are needed).

```nix
{ pkgs, lib, ... }:

{
  # Bootloader override — commonModules sets up GRUB + zen kernel (x86-only).
  # For aarch64 hosts, force systemd-boot and the default ARM kernel instead.
  boot = {
    kernelPackages = lib.mkForce pkgs.linuxPackages;

    loader = {
      grub.enable = lib.mkForce false;
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    hostName = "<hostname>";

    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    journald.extraConfig = "SystemMaxUse=200M";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
    persistent = true;
  };

  environment.systemPackages = with pkgs; [
    tmux
  ];
}
```

Note: If the architecture is `x86_64-linux`, omit the `boot` override block — it is only needed for aarch64 where zen kernel and GRUB are unavailable.

---

## Step 4 — Write the files

Write every file using the Write tool. Show the user the complete content of each file before writing. Do not skip any file.

## Step 5 — Git add the new host directory

After writing all files, run:

```bash
git -C /home/bosko/NixOS add hosts/<hostname>/
```

This is mandatory. Nix flake evaluation cannot see untracked files. Remind the user of this if they ask why.

## Step 6 — Show the flake.nix entry (do NOT edit automatically)

After writing files, show the user the exact `nixosConfigurations.<hostname>` block to add to `flake.nix`. Do NOT edit `flake.nix` automatically — show it, explain where it goes (after the last existing host entry, inside the `nixosConfigurations = {` attrset), and let the user add it or explicitly ask you to do it.

### flake.nix entry for a desktop host

```nix
# <Hostname — human-readable description>
<hostname> = self.lib.mkSystem {
  inherit inputs system nixpkgs;
  specialArgs = { inherit inputs self system; };
  modules = desktopModules ++ [
    # Machine-specific modules
    "${self}/hosts/<hostname>/hardware-configuration.nix"
    "${self}/hosts/<hostname>/environment.nix"
    "${self}/hosts/<hostname>/networking.nix"
    "${self}/dotfiles/common/modules/desktop-environments/<de>.nix"
    # "${self}/dotfiles/common/modules/nvidia.nix"   # uncomment if nvidia GPU
    # "${self}/dotfiles/common/modules/amd.nix"      # uncomment if amd GPU
  ];
};
```

Populate `<de>` with the chosen DE module name. Include or exclude the GPU lines based on what the user selected in Step 1 — leave them as comments if `none`, include them uncommented if applicable.

### flake.nix entry for a server host

```nix
# <Hostname — human-readable description>
<hostname> = self.lib.mkSystem {
  inherit inputs system nixpkgs;
  specialArgs = { inherit inputs self system; };
  modules = commonModules ++ [
    # Machine-specific modules
    "${self}/hosts/<hostname>/hardware-configuration.nix"
    "${self}/hosts/<hostname>/environment.nix"
    "${self}/hosts/<hostname>/networking.nix"
  ];
};
```

### flake.nix entry for a remote host (aarch64-linux)

```nix
# <Hostname — human-readable description>
<hostname> = self.lib.mkSystem {
  inherit inputs nixpkgs;
  specialArgs = {
    inherit inputs self;
    system = "aarch64-linux";
  };
  modules = commonModules ++ [
    "${self}/hosts/<hostname>/hardware-configuration.nix"
    "${self}/hosts/<hostname>/configuration.nix"
  ];
};
```

Note the difference: `inherit inputs nixpkgs;` (no `system`) and `system = "aarch64-linux"` in `specialArgs`. This mirrors how vpn-server is defined.

For a remote host with `x86_64-linux`, use the server pattern (inherit system, no explicit specialArgs override).

---

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
