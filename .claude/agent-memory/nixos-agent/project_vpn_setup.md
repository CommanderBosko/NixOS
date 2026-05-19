---
name: project-vpn-setup
description: WireGuard VPN setup via Oracle Cloud ARM VM — completed; remaining step is placing laptop private key
metadata:
  type: project
---

Oracle Cloud ARM VM (VM.Standard.A1.Flex, aarch64-linux) running NixOS at `150.136.232.63`. SSH as `root@150.136.232.63` with `~/.ssh/id_ed25519`.

**Why:** Bosko wants a WireGuard VPN server for routing gaming/laptop traffic.

**Status as of 2026-05-18: DEPLOYED AND WORKING (re-deployed successfully 2026-05-18 with natalie-laptop peer)**
- vpn-server NixOS config deployed, wg0 active at `10.10.0.1/24`
- WireGuard keys generated for gaming and laptop; private keys placed on vpn-server and gaming
- vpn.nix imported in gaming and laptop flake entries
- Per-host VPN addresses set in hosts/*/networking.nix
- Full-tunnel routing confirmed working: FORWARD chain ACCEPT policy, 1.3 GB forwarded, MASQUERADE rule active on enp0s6
- natalie-laptop placeholder peer (`NATALIE_LAPTOP_PUBLIC_KEY_PLACEHOLDER`) removed — it caused wg-quick-wg0.service to fail on every rebuild
- Firewall fixes applied: `trustedInterfaces = [ "wg0" ]` and `checkReversePath = "loose"` prevent FORWARD drops and asymmetric routing drops

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
- natalie-laptop: `YRrCAJ44V1y9uVkt7NWk8w61TDlU4o1G0MDLH0GSpSE=` (added 2026-05-18; IP 10.10.0.4)

**natalie-laptop SSH key (added to vpn-server root authorized_keys 2026-05-18):**
`ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnENcEPt+wOxR2EAu3BAcCXwErGJ4KfiANdPZH3oZfc kurthoernig@gmail.com`

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
