---
name: project-vpn-setup
description: WireGuard VPN setup via Oracle Cloud ARM VM — current state, decisions made, and next steps
metadata:
  type: project
---

Oracle Cloud ARM VM (VM.Standard.A1.Flex, aarch64-linux) is provisioned and running Ubuntu 24.04 at `150.136.232.63`. SSH confirmed working as `ubuntu@150.136.232.63` with `~/.ssh/id_ed25519`.

**Why:** Bosko wants a WireGuard VPN server for routing gaming/laptop traffic.

**Current state (as of 2026-05-18):**
- NixOS config for vpn-server is complete in `/home/bosko/NixOS/hosts/vpn-server/` (configuration.nix, hardware-configuration.nix, disko.nix)
- `disko` added as flake input (pinned in flake.lock), used for vpn-server disk partitioning
- `dotfiles/common/modules/vpn.nix` created — client config for gaming/laptop (not yet imported in their flake entries or networking.nix files)
- Files are git-staged but NOT committed

**Key decisions:**
- VPN subnet: `10.10.0.0/24` (NOT `10.0.0.0/24` which conflicts with Oracle's internal LAN)
  - vpn-server: `10.10.0.1`, gaming: `10.10.0.2`, laptop: `10.10.0.3`
- Oracle VM network interface: `enp0s6` (not `enp0s3` as originally guessed)
- Disk: `/dev/sda`, GPT, 512M EFI (label `boot`) + 100% ext4 (label `nixos`)
- Bootloader: systemd-boot (GRUB disabled via `lib.mkForce false` since commonModules enables GRUB)
- Kernel: `pkgs.linuxPackages` (default, not zen — zen not reliably available for aarch64)
- WireGuard listen port: 51820 server-side; clients don't set a fixed listen port

**Placeholders still needed before nixos-anywhere:**
- `hosts/vpn-server/configuration.nix`: `GAMING_PUBLIC_KEY`, `LAPTOP_PUBLIC_KEY`
- `dotfiles/common/modules/vpn.nix`: `SERVER_PUBLIC_KEY`
- Oracle Cloud security list: UDP 51820 must be opened in the VCN security rules

**Next steps:**
1. Get user confirmation, then run nixos-anywhere to install NixOS on the VM
2. After boot: generate WireGuard keys on gaming, laptop, and vpn-server; fill in placeholders
3. Import vpn.nix in gaming and laptop flake entries or networking.nix files; set per-host address
4. Open UDP 51820 in Oracle Cloud console security list (VCN → Security Lists)
5. Test connectivity; commit

**nixos-anywhere command:**
```
nix run github:nix-community/nixos-anywhere -- --flake /home/bosko/NixOS#vpn-server ubuntu@150.136.232.63
```

**How to apply:** Use this as current-state context when continuing the VPN setup; verify files still match before acting on specific details.
