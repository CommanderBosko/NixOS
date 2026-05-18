---
name: project-vpn-setup
description: WireGuard VPN setup via Oracle Cloud ARM VM — completed; remaining step is placing laptop private key
metadata:
  type: project
---

Oracle Cloud ARM VM (VM.Standard.A1.Flex, aarch64-linux) running NixOS at `150.136.232.63`. SSH as `root@150.136.232.63` with `~/.ssh/id_ed25519`.

**Why:** Bosko wants a WireGuard VPN server for routing gaming/laptop traffic.

**Status as of 2026-05-18: DEPLOYED**
- vpn-server NixOS config deployed, wg0 active at `10.10.0.1/24`
- WireGuard keys generated for all three hosts; private keys placed on vpn-server and gaming
- vpn.nix imported in gaming and laptop flake entries
- Per-host VPN addresses set in hosts/*/networking.nix
- All committed in git (commit a229f77)

**Key decisions:**
- VPN subnet: `10.10.0.0/24` (NOT `10.0.0.0/24` which conflicts with Oracle's internal LAN)
  - vpn-server: `10.10.0.1`, gaming: `10.10.0.2`, laptop: `10.10.0.3`
- Oracle VM network interface: `enp0s6`
- WireGuard listen port: 51820; clients use persistentKeepalive=25 (Oracle drops idle UDP after ~30s)
- Bootloader: systemd-boot (GRUB disabled via `lib.mkForce false`)
- Kernel: `pkgs.linuxPackages` (default, zen not available for aarch64)
- vpn.nix does full-tunnel routing (allowedIPs = 0.0.0.0/0 ::/0)

**WireGuard public keys:**
- vpn-server: `ijhN7KUmHx5TOLpKgyzJpzSvp49TkD0c2CTf32Cyu1U=`
- gaming: `M9KajsVX9wKLyeqz8F4kXbtelJYxYZP2b+cvkYMZ+nA=`
- laptop: `c4H2dY7dGuvanWpmpChT4vocjDPB+pbC8KeLJ2N8m3s=`

**Remaining step (manual, when on laptop):**
Place laptop's WireGuard private key:
```bash
sudo mkdir -p /etc/wireguard
sudo chmod 700 /etc/wireguard
echo 'cPxaQr/4U62p67MKrNlY39SAWV6SMCBt4GfOEBR0E0E=' | sudo tee /etc/wireguard/private.key
sudo chmod 600 /etc/wireguard/private.key
```
Then run `rebuild` on laptop to activate `wg-quick-wg0.service`.

**To activate on gaming now:**
```bash
sudo mkdir -p /etc/wireguard
sudo chmod 700 /etc/wireguard
echo 'KPtXMG5S9UBaDRXEE/uJouPsIBuXmWB6+cHxPlWAr0s=' | sudo tee /etc/wireguard/private.key
sudo chmod 600 /etc/wireguard/private.key
rebuild  # activates wg-quick-wg0.service
```

**Oracle Cloud note:** UDP 51820 must be open in the VCN security list. If not already done, open it in the Oracle Cloud console: VCN → Security Lists → Ingress Rules → add UDP 51820.

**How to apply:** Use this as current-state context when continuing the VPN setup.
