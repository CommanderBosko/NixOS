# Pi deploy gotchas

Background for the deploy-pi-host skill. Load it before the first deploy to a newly migrated Pi, or when a build, hand-off or verify result is surprising.

## Building

- **Only gaming builds aarch64.** It sets `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`, so the Pi's toplevel is built under QEMU user-mode emulation. The laptops have no such handler, so nix finds no aarch64-linux builder and fails. `pi-deploy.sh build` refuses early on any machine that is neither native aarch64 nor has the binfmt handler enabled.
- **Cold builds are slow.** Most of a toplevel comes from the binary cache, but a kernel, initrd or firmware change (typically a nixpkgs / `flake.lock` bump) can pull in or compile a lot under emulation and run well past the 10-minute tool timeout. Run `build` in the background and wait for the completion notification. `build --dry-run` shows up front what would be built or fetched and writes nothing.
- **Never build on the Pi.** It has 1-4 GB of RAM and an SD card; a build OOM-kills or thrashes it. Do not use `--build-host` pointing at the Pi either.
- **Nix sees tracked files only.** New files need `git add` before they exist for the flake. Tracked-file edits are included even when uncommitted, which is why `build` WARNs about a dirty tree: the system you ship would not match git HEAD.
- **`PI_ASSUME_BUILDER=yes|no`** is a TEST-ONLY hook that makes `pi-deploy.sh` skip the real "can this machine build aarch64" probe; it exists so the test suite does not depend on the machine it runs on. Do not set it for real runs.

## The hand-off command

- `nixos-rebuild <mode> --flake <repo>#<host> --target-host <user@ip> --elevate sudo --ask-elevate-password` builds (already cached by the prior `build` step), copies the closure to the Pi and activates it there with sudo. This is the same remote form `fleet-rollout` uses.
- **Flag aliases** on the installed nixos-rebuild: `--ask-sudo-password` is an alias for `--elevate sudo --ask-elevate-password`; `--sudo` aliases `--elevate sudo` (no password prompt, so it needs NOPASSWD, which no host has); `--use-remote-sudo` is deprecated. The script prints the canonical long form.
- **Mandatory hand-off.** Remote activation needs root on the Pi (polkit denies the unprivileged path) and there is no NOPASSWD sudo anywhere, so Claude cannot run it. Print one command, the user runs it in their own terminal (no `!` prefix: sudo has no TTY there), and confirms.
- **Run it where you built.** `--target-host` evaluates and builds on the machine that runs the command, using that machine's checkout. On anything but gaming it would redo the aarch64 build and fail.
- **bosko is a nix trusted-user on the Pi**, so the closure copy is accepted without a signing key. If a copy is refused with a signature error, the Pi's nix `trusted-users` no longer includes bosko — fix that in the host config, not by disabling signature checks.
- **Do not reach for `nh` here.** In this repo `nh os` is the local desktop host's tool; remote hosts are deployed with `nixos-rebuild --target-host`.
- **SSH can drop mid-switch.** A switch that restarts Tailscale or NetworkManager can cut the ssh session carrying the deploy (famdash is Wi-Fi only). The activation itself normally continues on the Pi under systemd, so wait a minute, then run `verify` before retrying; do not start a second deploy on top of a running one.

## boot vs switch on a Pi

- **switch** activates immediately: `/run/current-system` moves to the new toplevel. Kernel, initrd, firmware and device-tree changes are NOT applied until a reboot; `verify` shows that as WARN "reboot pending (kernel/initrd changed)".
- **boot** only registers the generation and rewrites the Pi's bootloader entry (U-Boot reading extlinux, not systemd-boot/EFI); nothing runs until a reboot. Until then `/run/current-system` is still the old system, so `verify --mode boot` reports "staged, not running" as a WARN, while `verify --mode switch` calls the same state a FAIL (activation did not complete). After the reboot hand-off (`pi-deploy.sh cmd <host> --reboot`, i.e. `ssh -t <user@ip> sudo systemctl reboot`) both modes PASS.
- **After a reboot** the Pi is back on the tailnet about 30 s after power-on, sometimes longer on Wi-Fi. A just-rebooted Pi may show a transient failed unit (network, tailscale); give it a minute and re-run `verify` once before treating it as a failure.
- **`/run/booted-system` never follows a switch.** That is the point of the reboot check: `verify` compares its kernel, initrd and kernel-modules with `/run/current-system`'s. It always prints the booted-system path as INFO so a stale-looking value is not mistaken for a failed deploy.

## pi-hole is the household's DNS

- **Pick the window with the user** (AskUserQuestion), never your own "quiet" slot. A `switch` that restarts `pihole-ftl` drops DNS for a few seconds; a reboot (boot mode) for a minute or two until FTL is up. Prefer `switch` unless the change needs a reboot (kernel, initrd).
- **FTL reruns gravity at every start** (about a minute and ~260 MB peak on the 1 GB board); a freshly started FTL answers right away, but ad domains resolve normally until gravity finishes.
- **Clients and groups come from sops** (`pihole-clients.service`, re-applied after every FTL restart); lists come from `hosts/pi-hole/adlists.nix`. Declared lists and clients are re-applied additively (nothing is deleted), so change declared entries in Nix, not in the web UI.
- **Safety net:** the old Pi OS card image (`~/pi-backups/pi-hole/old-card.img.zst`) is the rollback of the migration, not of a deploy; a bad deploy rolls back with `nixos-rebuild switch --rollback` (hand-off).

## Not part of day-2 deploys

- **The expand-root-partition fix is first-boot only.** modules/pi-sd-image.nix (shared by famdash and pi-hole) overrides nixpkgs' `expand-root-partition` unit (util-linux 2.42 pads the `lsblk` MAJ:MIN column, so sfdisk rejects the partition number). The unit only runs while `/nix-path-registration` exists, i.e. on the first boot of a flashed image, so ordinary deploys never exercise it. If `expand-root-partition.service` shows up in `verify`'s failed-units on a freshly flashed Pi, that is a first-boot problem, not something the deploy broke. Manual fix on the Pi: `echo ",+," | sudo sfdisk -N2 --no-reread /dev/X; sudo partx -u /dev/X; sudo resize2fs /dev/XN2` (`X` is the card device, `XN2` its second partition). A new Pi host gets the override by importing modules/pi-sd-image.nix. It worked on pi-hole's first boot (2026-11-27: root partition grown to 99% of the card, no manual step).
- **Cleanup.** This skill never deletes generations: the previous one is the rollback target. A Pi that sets `nix.gc` (famdash: weekly, older than 7 days) trims on its own. `cleanup-host` (nh clean plus flatpak) is a desktop helper; whether a Pi belongs in a fleet loop's cleanup step is `fleet-rollout`'s call.
- **Rollback** is its own skill and its helper script reads the local generations. For the Pi, the user's hand-off is `ssh -t <user@ip> sudo nixos-rebuild switch --rollback`.

## How it fits with the other skills

- **`fleet-rollout`** deploys the committed config across all flake hosts one at a time, with a dry-run/build gate, a `fleet-status` sweep, reboots and cleanup, a Training Mode toggle and per-run memory files. Use it for more than one host; use this skill for "update just the Pi". Both use the same `--elevate sudo --ask-elevate-password` hand-off, and famdash is a normal `fleet-rollout` participant once it is in `.flakeHosts`. pi-hole is not: it carries a `fleetExclude`, so a default fleet run skips it and it is always deployed here, on its own.
- **`fleet-status`** reads every flake host (generation, failed units, staged, reboot) but cannot say whether a host runs a *specific* toplevel; `pi-deploy.sh verify` can, via `--expect`. Use `fleet-status` afterwards for the whole-fleet picture.
- **`verify-service`** sweeps one named unit in depth; `verify` here only checks that no unit is failed.
- **`pi-sd-flash` + `pi-cutover`** handle the first install and identity handover. Once the Pi shows up in `.flakeHosts` and `verify` passes, day-2 changes come here.
