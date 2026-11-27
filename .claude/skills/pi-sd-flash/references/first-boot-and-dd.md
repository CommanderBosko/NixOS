# dd behaviour, first boot, and the sd-image gotchas

Load this when the user asks "is it stuck?", when planning the first boot after a flash,
or when a Pi host config is being added or changed. The cutover itself (service data,
DNS, verification) belongs to the `pi-cutover` skill; this page only covers what happens
on and around the media.

## While dd runs

- `dd ... conv=fsync status=progress` reports roughly 1.4 GB/s at first (it is only
  filling the page cache), then sits silent for minutes while the real flush to the
  stick or card happens at about 11 MB/s. That silence is normal. Do not interrupt it;
  an interrupted write leaves half an image and the script's label check will fail.
- The script waits for the flush, remounts partition 2, seeds the key (and the optional
  Tailscale state), compares each seeded file with its source, and only then prints
  `DONE:`. Do not remove the media before that line.
- The flash path of `flash-pi-media.sh` cannot be exercised without real media, so it is
  kept as close as possible to the hand-run script that flashed famdash. Its tests cover
  validation, planning and refusals only. Treat the first real flash on a new machine as
  one to watch.

## Powering things down and up

- A halted Pi 4 keeps blinking its activity LED. Unplugging is safe once it has stopped
  answering ping; do not wait for the LED.
- Never power the old media and the new media at the same time: two nodes with the same
  host key and Tailscale identity fight over the tailnet name.
- First boot reaches the tailnet roughly 30 seconds after power-on. Before trusting the connection, the host key the Pi serves must equal the
  pre-generated public key (`ssh-keyscan -t ed25519 <ip>` against
  `$PI_BACKUP_DIR/ssh-host/ssh_host_ed25519_key.pub`). A mismatch means the key was not
  seeded and sops cannot decrypt. A stale `known_hosts` entry from the old OS needs
  `ssh-keygen -R <ip-or-name>`. Both checks are `pi-cutover`'s; they are listed here so a
  failed first boot is read correctly.

## The expand-root-partition bug (every Pi host config needs the override)

nixpkgs' sd-image runs a unit, `expand-root-partition`, on first boot to grow partition 2
to fill the card. With util-linux 2.42 `lsblk` pads its MAJ:MIN column, so the partition
number is read as `'2  '` and `sfdisk` aborts with "failed to parse partition number".
The unit only runs while `/nix-path-registration` exists (first boot), so the failure is
easy to miss and the fix has not been proven at runtime.

- Fix: `hosts/famdash/configuration.nix` replaces the unit's script with a
  `lib.mkForce`d copy that strips whitespace (`tr -d '[:space:]'`) before parsing. **Every
  Pi host config that imports the sd-image module needs the same override**, including
  pi-hole's. Check with `grep -n expand-root-partition hosts/<host>/*.nix` before building.
- Deferred cleanup: when the second Pi host is added, extract the override into a shared
  `modules/pi-sd-image.nix` and confirm the famdash toplevel's outPath is unchanged
  (`nix eval --raw "$(pi_flake_ref toplevel).outPath"` before and after) so the live Pi
  does not get a pointless rebuild.
- Manual fix on a Pi that booted with a small root (`/dev/X` is the whole device, e.g.
  `/dev/mmcblk0` or `/dev/sda`; partition 2 is `/dev/Xp2` when the name ends in a digit,
  else `/dev/X2`):
  ```bash
  echo ",+," | sudo sfdisk -N2 --no-reread /dev/X
  sudo partx -u /dev/X
  sudo resize2fs /dev/X2        # or /dev/Xp2
  ```
  That is a root-on-the-Pi step, so it is a hand-off to the user.

## Why not nixos-anywhere

It is not an option on these Pis: the Pi OS kernel lacks kexec, famdash is Wi-Fi only
(the installer would have no network after the kexec), and the install would wipe the
only card the Pi boots from. The route is: build the aarch64 sdImage on gaming, flash
spare media, swap the media.

## Building

The image is built on gaming only (`boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`
runs aarch64 binaries under QEMU). Never build on the Pi: 1-4 GB of RAM is not enough
for a closure build. `build-image.sh` uses `--no-link`, so the image has **no GC root**:
flash it soon or copy it somewhere permanent before any cleanup or garbage collection
runs on gaming.
