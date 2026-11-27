---
name: pi-sd-flash
description: Build the NixOS SD image for a Raspberry Pi on gaming and get it onto an SD card or USB stick with the host key (and optionally the Tailscale state) seeded. The agent prepares and validates; the user performs every sudo and physical step. Use when the user says "flash the pi", "build the pi image", "pi sd flash", "make a boot card for <host>", "flash a NixOS card", "seed the sd card", "replace a dead SD card".
version: 0.1.0
---

# Pi SD Flash

Turn a Pi host's flake config into flashed, key-seeded boot media, with every privileged or physical step handed to the user. (Bucket: Orchestration)

This skill ends when the media is flashed and removed. It is **not**:

- `new-host`: scaffolding the host's config files and flake entry (this skill needs the config to exist already).
- `pi-cutover`: backing up and moving the old Pi's data, power-over, first-boot verification, DNS/tailnet switch. Hand off to it after the flash.
- `deploy-pi-host`: pushing config changes to a Pi that already runs NixOS (`nixos-rebuild --target-host`).

## Arguments

Parse from the request: the **host** name (an alias or key from `.claude/hosts.json`, e.g. `famdash`, `pi-hole`), and optionally an explicit Tailscale IP for a Pi that is not in `hosts.json` yet, a preferred route (A/B/C below), and a `tailscaled.state` file path to seed. If the host is missing, ask. "Replace a dead SD card" means flash only: reuse the existing key pair, skip any cutover, and see the end of `references/routes.md`.

## Steps

1. **Resolve the host and its key state.**
   - The config must evaluate: `bash -c 'source /home/bosko/NixOS/.claude/lib/pi-host.sh; pi_load "$0" "$1"; nix eval --raw "$(pi_flake_ref image).drvPath"' <host> [<ip>]` (run it through `bash -c`: the helper's `pi_die` exits the shell that sourced it). If it fails because the host is not in the flake, stop and point at `new-host`; check that the host config carries the `expand-root-partition` override (`grep -n expand-root-partition hosts/<host>/*.nix`, see `references/first-boot-and-dd.md`).
   - Key state: `.claude/skills/pi-sd-flash/scripts/gen-host-key.sh <host> --check`. No key yet: run it without a flag (offline, unprivileged), then register the recipient, `sops updatekeys` and `git add` per `references/sops-bootstrap.md` **before building**. Key exists: `--show` and confirm it reports `registered in .sops.yaml: YES`.
2. **Build the image** on gaming: `.claude/skills/pi-sd-flash/scripts/build-image.sh <host> [--ip IP]` (try `--dry-run` first if unsure). It is a long emulated build: run it in the background and wait. Capture the `IMAGE: <path>` line. If this machine is not gaming it refuses; do not build elsewhere and never on the Pi.
3. **Choose the route.** Ask with AskUserQuestion (`references/routes.md` has each route in full): **A** reader/stick on gaming (recommended first when `lsblk` on gaming already shows removable media), **B** flash from another machine with a reader via `stage-remote.sh` (natalie-laptop has worked), **C** USB-stick boot, which needs the old Pi's EEPROM boot order changed first. Then have the user plug the media in and confirm the device from `lsblk` on the machine that holds it (model + size; an empty reader slot is size 0). Ask which `tailscaled.state` to seed, if any.
4. **Validate, read-only.** Route A: `flash-pi-media.sh --check <dev>` then `--plan <dev> <image> <keydir> [state]`. Route B: `stage-remote.sh <host> <flasher> <image> <keydir> [state] --device <dev>` (add `--dry-run` first), which stages, runs the remote `--check` and `--plan`, and prints both hand-offs. Fix any `REFUSING:` line; do not work around a guard.
5. **Hand off the flash.** Print exactly ONE command (wording in `references/routes.md`), tell the user to run it in their own terminal (no `!` prefix; sudo has no TTY here), mention the dd silence, and wait for them to confirm `DONE:`. Route B also hands off the staged-dir cleanup (`ssh -t <target> rm -rf <dir>`, user-run: remote deletes are blocked for the agent and the dir holds the private key). Route C's EEPROM edit and reboot are user steps too.
6. **Close out.** The user removes the media and must not power the old card or disk together with the new one. Tell them the next skill: `pi-cutover` (or `deploy-pi-host` for a replaced card whose image is older than the deployed generation). Do not start the cutover from here.

## Gotchas

- Never run anything privileged or physical yourself: sudo, flashing, power, reboot, remote `rm -rf`. One command, user's terminal, wait for confirmation.
- `nixos-anywhere` is not an option on these Pis (no kexec on the Pi OS kernel, Wi-Fi-only hosts, it would wipe the only card). The route is build on gaming, flash spare media, swap.
- Order matters: register the sops recipient and re-encrypt **before** the build, or the image carries files the Pi's key cannot decrypt.
- A path flake only sees git-tracked files; new host files, modules and secrets need `git add` before the build (`build-image.sh` warns).
- `build-image.sh` leaves no GC root; flash soon or copy the image somewhere permanent.
- dd with `conv=fsync` prints ~1.4 GB/s then goes silent for minutes while the real flush runs; that is normal. A halted Pi 4 keeps blinking; unplugging is safe once it stops answering ping.
- Keys and state live in `~/pi-backups/<host>/` (0700, outside the repo). The scripts take file paths and never print key material, and nothing from there goes into the repo or the Nix store.
- The sd-image `expand-root-partition` unit fails on first boot (padded lsblk output) unless the host config carries the `lib.mkForce` override.
- `flash-pi-media.sh`'s write path cannot be run without real media; its tests cover validation and refusals only.

## Scripts

- `.claude/skills/pi-sd-flash/scripts/build-image.sh <host> [--dry-run] [--ip IP]` (Step 2). Builds the sdImage on gaming and prints `IMAGE: <path>`.
- `.claude/skills/pi-sd-flash/scripts/gen-host-key.sh <host> [--ip IP] [--check|--show]` (Step 1). Pre-generates the host key pair; refuses to overwrite; prints only public material.
- `.claude/skills/pi-sd-flash/scripts/flash-pi-media.sh --check <dev> | --plan <dev> <image> <keydir> [state] | <dev> <image> <keydir> [state]` (Steps 4-5). Self-contained; flash mode is root-only and user-run. Exit 0 ok, 1 refused (`REFUSING:`), 2 usage.
- `.claude/skills/pi-sd-flash/scripts/stage-remote.sh <host> <flasher> <image> <keydir> [state] [--device DEV] [--dry-run]` (Steps 4-5, route B). Stages to a 0700 dir on the other machine and prints the two hand-offs.
- Each script has a sibling `<name>.test.sh`; run them with `bash <path>`.

## References

- `references/routes.md`: routes A/B/C in full with per-route hand-off wording and the dead-card variant. Load in Step 3.
- `references/first-boot-and-dd.md`: dd silence, LED and power rules, first-boot timing, the expand-root-partition bug and manual fix, why not nixos-anywhere. Load when something looks stuck or a Pi host config is being edited.
- `references/sops-bootstrap.md`: the pre-boot sops variant for a Pi. Load in Step 1 when a key must be generated or registered.
