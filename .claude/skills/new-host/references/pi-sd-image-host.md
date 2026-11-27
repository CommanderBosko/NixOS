# Raspberry Pi (SD-image) host type

Load this when `new-host` Step 1 routes a Raspberry Pi (or any other SD-image board) here, or when you are migrating a Pi from Pi OS to NixOS. A Pi is not one of the `desktop` / `server` / `remote` types, so none of the `assets/` templates apply. This file is the runbook; the heavy lifting is split across three sibling skills, and this file says when to hand off to each.

The shared Pi base lives in `modules/pi-sd-image.nix` (image import, firmware, the shared networking imports, persistent capped journald, zram, weekly `nix.gc` and the expand-root-partition fix). The LIVING examples are `hosts/famdash/configuration.nix` (Wi-Fi, a dashboard app; migrated 2026-11-26) and `hosts/pi-hole/configuration.nix` (Ethernet, the DNS appliance; migrated 2026-11-27). A new Pi host imports the shared module and adds only its `stateVersion`, `image.baseName`, link config, firewall ports and app services. Do not paste their contents into docs or into this file: they drift, and the files are the source of truth. `hosts/famdash/famdash.nix` and `hosts/pi-hole/{pihole,clients,adlists}.nix` are the apps' services, not part of the Pi pattern.

**Hand-off rule for the whole runbook.** Claude never runs anything privileged or physical: `sudo`, flashing a card, power cycles, reboots and remote deletes (`rm -rf`, `shred`) on other hosts are all hand-offs. Print exactly ONE command, tell the user to run it in their own separate terminal (no `!` prefix: `sudo` gets no TTY that way), and wait for their confirmation before continuing.

## 0. What differs from the `remote` template (and why)

A Pi boots U-Boot/extlinux from an SD image. The `remote` template assumes systemd-boot/EFI plus a generated `hardware-configuration.nix`, so it does not fit. A Pi host instead (most of this list now lives in `modules/pi-sd-image.nix`; the host file sets `image.baseName`, `stateVersion`, the link config and the firewall):

- **Has no `hardware-configuration.nix` and no `disko.nix`.** The upstream image module declares the card layout. Import it with `modulesPath`: `"${modulesPath}/installer/sd-card/sd-image-aarch64.nix"` (so the module arguments include `modulesPath`).
- **Sets `image.baseName = "<host>"`**, which names the flashable image file so it is easy to find after the build.
- **Freezes `system.stateVersion`** at the NixOS release current at install time. Never bump it on upgrades.
- **Enables `hardware.enableRedistributableFirmware`** (the onboard Wi-Fi chip needs its blobs).
- **Reuses the shared networking modules**: `modules/desktop-networking.nix` (despite the name: NetworkManager, DNS via pi-hole's tailnet IP with a 1.1.1.1 fallback, firewall base, chrony with literal-IP NTP servers because a Pi has no RTC, and the SSH `AllowUsers` pin to bosko) and `modules/tailscale.nix`. Both come in by `imports` in the host file, not through `commonModules`.
- **Gets its link config in the host file.** Wi-Fi Pi: a NetworkManager `ensureProfiles` profile whose SSID and password come from a sops env file (`environmentFiles`), so nothing sensitive lands in this public repo, plus the regulatory-domain lines. Ethernet-only Pi (pi-hole): no Wi-Fi profile and no Wi-Fi secret at all.
- **Uses a per-interface firewall** (`networking.firewall.interfaces.<iface>.allowedTCPPorts`) for the app's ports, on the LAN link and on `tailscale0` only. Check the real interface names on the running NixOS system: the Pi OS name is not reliable, and a wrong name fails closed.
- **Keeps logs across power cuts** with persistent journald capped in size (SD cards wear out).
- **Enables zram swap** (these boards have 1-4 GB and no swap otherwise) and a weekly `nix.gc`.
- **Is headless**: `commonModules` only, no DE, no Home Manager, no flatpak.
- **Carries the expand-root-partition override** (see "Known bug" below).

### Files to create or edit

1. `hosts/<host>/configuration.nix`: import `../../modules/pi-sd-image.nix` (see famdash's or pi-hole's file for the shape), then add `stateVersion`, `image.baseName`, the link config, the firewall ports, hostname-derived names and secret names.
2. `flake.nix`: add the host. Show it first and edit only when the user asks (same rule as `new-host` Step 6). The shape is the famdash entry, with the name and path changed:

   ```nix
   <host> = mkSystem {
     name = "<host>";
     system = "aarch64-linux";
     modules = commonModules ++ [
       "${self}/hosts/<host>/configuration.nix"
     ];
   };
   ```

   `commonModules` (not `desktopModules`) is deliberate. Read famdash's entry in `flake.nix` rather than trusting this snippet if they ever disagree.
3. `.claude/hosts.json`: add the name to `.flakeHosts` and fill the host entry: `ssh` = `bosko@<host>` (the host pins SSH `AllowUsers` to bosko, and `ssh.nix` derives the alias user from this field), `ip` (LAN, drifts, reference only), `tailscaleIp` (stable; the one everything dials), `local: true`, `flakeHost: true`, `desktop: false`, `arch: "aarch64-linux"`, `envFile: "hosts/<host>/configuration.nix"`, and a `notes` string (what the box is, how it boots, never build on-device). An existing entry that still describes the Pi OS era gets its `flakeHost` flipped and its `notes` rewritten. Edit only when the user asks, then run `/home/bosko/NixOS/.claude/lib/check-hosts-json.sh` to confirm it agrees with the flake's real `nixosConfigurations` (needs both edits in place and `git add`ed).
4. `git add hosts/<host>/` and every other new file. The flake only sees git-tracked files.
5. Eval check before any build: `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` (evaluation only, so no aarch64 builder needed). The dry-run skill is for the local x86 host and does not apply to a Pi.

**Why not nixos-anywhere:** it needs kexec, which the Pi OS kernel lacks, and it would wipe the only boot card of a box that may have no other way in (famdash is Wi-Fi only). The route is always: build the image on gaming, flash a spare card or stick, swap the media.

## 1. sops: pre-generate the host key BEFORE first boot

The generic `new-host` flow (`references/sops-registration.md`) registers a host after its first boot. A Pi flips that order, because a Wi-Fi-only Pi that cannot decrypt its Wi-Fi env on first boot is unreachable, and its login hashes would not decrypt either.

1. Generate the Pi's SSH ed25519 host key on this machine with `.claude/skills/pi-sd-flash/scripts/gen-host-key.sh` (the skill documents its arguments); you need the age recipient it derives, which is public. The private key stays outside the repo (by default under `~/pi-backups/<host>/`, 0700) and is copied onto the flashed media's `/etc/ssh` later. It never enters the Nix store or the repo, and Claude never prints it.
2. Register the recipient exactly as `references/sops-registration.md` steps 2-4 describe: an anchor under `keys:` in `.sops.yaml`, an entry in the `secrets/common.yaml` rule (headless, so NOT `desktop.yaml`), then `sops updatekeys secrets/common.yaml`. Use the **`add-secret`** skill for any new secret.
3. **Wi-Fi Pi only:** create `secrets/hosts/<host>.yaml` holding the env file the profile substitutes (famdash's profile references `FAMDASH_WIFI_SSID` and `FAMDASH_WIFI_PSK`; use matching `<HOST>_...` names). Give it its own `creation_rule` in `.sops.yaml` with `[*admin, *<host>]`, and declare `sops.secrets."<host>-wifi-env".sopsFile` in the host file. The user supplies the values; Claude never prints them. An Ethernet-only Pi skips this step.
4. `git add .sops.yaml secrets/` before building. The image embeds the already-encrypted file, so every sops edit must be finished first, or the first boot will not decrypt.

## 2. Build and flash: `pi-sd-flash` skill

Hand off to the `pi-sd-flash` skill (`.claude/skills/pi-sd-flash/`). It owns `scripts/build-image.sh`, `scripts/gen-host-key.sh`, `scripts/flash-pi-media.sh` and `scripts/stage-remote.sh`. It builds the sdImage on gaming and flashes and seeds a spare card or stick. The build only works where the aarch64 binfmt handler exists (gaming sets `boot.binfmt.emulatedSystems`), never on the Pi itself.

Things to expect: gaming has no SD reader, so flashing goes to a USB stick or a card in a USB reader. `dd ... conv=fsync` reports ~1.4 GB/s at first (RAM cache) and then sits silent for minutes while the real ~11 MB/s flush happens. That is normal. The flash command needs `sudo`, so it is a hand-off.

## 3. Cutover: `pi-cutover` skill

Hand off to the `pi-cutover` skill (`.claude/skills/pi-cutover/`): freeze and snapshot the old node, swap the media, verify the new boot, restore state, compare old against new, and roll back if needed. Two rules worth repeating here: never power the old and new media together, and the Tailscale identity is kept by copying the old node's `tailscaled.state` onto the new media, so the Pi keeps its tailnet name and IP.

## 4. Day 2: `deploy-pi-host` and `fleet-rollout`

- **One Pi:** the `deploy-pi-host` skill (`.claude/skills/deploy-pi-host/`) builds the toplevel on gaming, hands off `nixos-rebuild ... --target-host`, and verifies. Never build on the Pi.
- **The whole fleet:** the `fleet-rollout` skill picks the Pi up automatically once it is in `.flakeHosts`. Its build gate needs a machine with the aarch64 binfmt handler, so run it from gaming (see its Gotchas), or use the single-Pi path (`deploy-pi-host`).
- Health checks: `fleet-status` (read-only sweep of every flake host) and `verify-service` (one unit on one host).
- A flake host's first install is always section 2 plus section 3 here, never `deploy-pi-host`.

## Known bug to carry into every Pi host

nixpkgs' sd-image module has a unit, `expand-root-partition`, that grows the root partition on first boot. It fails on current nixpkgs: util-linux 2.42 pads the `MAJ:MIN` column of `lsblk`, so the partition number reads `'2  '` and `sfdisk` aborts with `failed to parse partition number: '2  '`.

`modules/pi-sd-image.nix` carries the fix, a `lib.mkForce`d `systemd.services.expand-root-partition.script` that is the upstream script with whitespace stripped (`tr -d '[:space:]'`) before the partition number is parsed. A Pi host gets it by importing that module.

Caveats:

- The unit only runs while `/nix-path-registration` exists, which is the first boot of a fresh image. **Verified on real hardware:** pi-hole's first boot (2026-11-27) grew the root partition to 99% of the card with the override, no manual step (famdash's first boot hit the original bug, which is why the override exists).
- If the unit still fails on a first boot, grow the partition by hand on the Pi (device `X`, partition `XN2`, for example `sda` and `sda2`, or `mmcblk0` and `mmcblk0p2`): `echo ",+," | sfdisk -N2 --no-reread /dev/X; partx -u /dev/X; resize2fs /dev/XN2`. This needs root, so it is a hand-off.
- When upstream fixes the module, drop the override.

## Shared module: done

`modules/pi-sd-image.nix` was extracted with the pi-hole PR (2026-11-27) as a pure move: famdash's toplevel output path was identical before and after. That comparison is still the proof for any further move: run `nix eval --raw .#nixosConfigurations.famdash.config.system.build.toplevel.outPath` before and after (with new files `git add`ed) and require identical output. Run it from gaming: the private `famdash` flake input is fetched over SSH, and gaming has that access.

## pi-hole (migrated 2026-11-27)

The DNS appliance followed this workflow; see `.claude/skills/pi-cutover/references/dns-appliance.md` for the record. Facts worth knowing for the next Pi:

- **Hardware:** Pi 4B with 1 GB RAM. Never build on it; zram and the journald cap matter more here than on famdash. Gravity peaks at ~260 MB.
- **Network:** Ethernet only (NIC `end0`, not `eth0`), static LAN address in a NetworkManager `ensureProfiles` profile that is not bound to an interface name. No Wi-Fi profile or Wi-Fi secret.
- **It is the tailnet's global nameserver, 100.92.242.60.** The identity survived the swap because the old node's `tailscaled.state` was copied onto the new card. `modules/desktop-networking.nix` points every flake host at that IP with a 1.1.1.1 fallback; the pi-hole host overrides `networking.nameservers` to itself first (`127.0.0.1`, then 1.1.1.1).
- **Secrets:** `secrets/hosts/pi-hole.yaml` holds the web password hash and the client list (names and MACs); both are sops secrets and are never printed.
- **Fleet:** `fleetExclude` in `hosts.json` keeps it out of `fleet-rollout`; update it with `deploy-pi-host` in a window the user picks.
- **Timing:** a DNS outage hits the whole household, so the cutover window is the user's call. Do not schedule or start a swap on your own initiative; plan it, then ask.
