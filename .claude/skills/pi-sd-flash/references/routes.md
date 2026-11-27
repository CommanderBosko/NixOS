# The three routes to get an image onto media

Load this in Step 3 of the skill, once the image is built and you must pick where the
card or stick gets written. All three routes end in the same script,
`flash-pi-media.sh`; they differ only in which machine holds the media and what has to
be true of the Pi's firmware first.

Rules that hold for every route:

- The agent prepares and validates; the **user** runs the one privileged command in
  their own separate terminal (no `!` prefix: sudo has no TTY there). Print exactly one
  command, then wait for the user to say it finished.
- Before any write: `lsblk` on the machine that holds the media, then the read-only
  `--check` and `--plan` modes. An empty reader slot shows up as a disk of size 0; a
  card that is present shows its real size. Internal disks are refused by the script's
  guards, but never pass one by habit.
- `<keydir>` is `$PI_BACKUP_DIR/ssh-host` (default `~/pi-backups/<host>/ssh-host`, made
  by `gen-host-key.sh`). `[state]` is an optional `tailscaled.state` file path; its
  contents are never read or printed.
- Host names, SSH targets and Tailscale IPs come from `.claude/hosts.json`, never from
  memory.

## Route A: reader or stick on this machine (gaming)

Gaming has no built-in SD reader. This route works only when a USB stick or a USB card
reader is plugged into gaming.

1. `lsblk -o NAME,SIZE,TYPE,TRAN,RM,MODEL,LABEL,MOUNTPOINTS` before and after the user
   plugs the media in; the disk that appeared is the candidate (`/dev/sdX`, or
   `/dev/mmcblkN` for a built-in reader). Confirm model and size with the user.
2. Read-only validation (agent runs these):
   ```bash
   bash /home/bosko/NixOS/.claude/skills/pi-sd-flash/scripts/flash-pi-media.sh --check /dev/sdX
   bash /home/bosko/NixOS/.claude/skills/pi-sd-flash/scripts/flash-pi-media.sh --plan /dev/sdX <image> <keydir> [<state>]
   ```
3. Hand-off wording (the agent prints this and stops):

   > Run this in your own terminal. It asks for your sudo password, then makes you
   > retype the device path to confirm the erase:
   >
   > `sudo bash /home/bosko/NixOS/.claude/skills/pi-sd-flash/scripts/flash-pi-media.sh /dev/sdX <image> <keydir> [<state>]`
   >
   > dd shows ~1.4 GB/s and then goes silent for minutes: that is the real flush, leave
   > it. Tell me when it prints `DONE:` and you have removed the media.

If the script says a tool is missing (zstd on a borrowed machine), it prints a
`nix shell nixpkgs#... -c sudo env "PATH=$PATH" bash ...` form of the same command.

## Route B: flash from another machine (`stage-remote.sh`)

Use this when the reader lives on a different machine. On the famdash migration,
natalie-laptop's USB "Multiple Card Reader" showed up as `/dev/sda` there (an internal
disk on gaming, so device names are only meaningful on the machine that holds the
media: always run `lsblk` **there**).

1. Pick the flasher from `.claude/hosts.json` (name or alias, or a plain `user@host`).
   Have the user insert the card, then list disks over SSH (read-only; the `ssh-host`
   skill has the connection details):
   `ssh <flasher> lsblk -o NAME,SIZE,TYPE,TRAN,RM,MODEL,LABEL,MOUNTPOINTS`.
   Confirm the device with the user.
2. Preview, then stage and check:
   ```bash
   .claude/skills/pi-sd-flash/scripts/stage-remote.sh <host> <flasher> <image> <keydir> [<state>] --device /dev/sdX --dry-run
   .claude/skills/pi-sd-flash/scripts/stage-remote.sh <host> <flasher> <image> <keydir> [<state>] --device /dev/sdX
   ```
   This copies the image, `flash-pi-media.sh`, the key pair and the optional state into a
   0700 `/tmp/pi-flash.XXXXXX` on the flasher, verifies the image size matches, and runs
   `--check` and `--plan` there. The `--plan` run also proves the tools (zstd) exist on
   that machine before anyone types a sudo password. Without `--device` the hand-off
   carries a `<DEVICE>` placeholder instead.
3. Hand-off 1, printed by the script (the user runs it):
   `ssh -t <target> sudo bash <dir>/flash-pi-media.sh <dev> <dir>/image.img.zst <dir>/keys [<dir>/tailscaled.state]`
4. Hand-off 2, printed by the script (the user runs it afterwards, even if the flash is
   abandoned): `ssh -t <target> rm -rf <dir>`. The staged dir holds the **private** host
   key and the Tailscale identity; it must not stay on a machine that is not the Pi.
   The agent never runs this itself: remote deletes are blocked by the auto-mode
   classifier, so they are always a hand-off.

If staging fails halfway, the script still prints the cleanup hand-off for whatever dir
it had created.

## Route C: USB-stick boot (EEPROM change first)

Use this when no SD reader is reachable but a USB stick is: flash the stick with route A
or B, and make the Pi boot from it. An older Pi 4 EEPROM ships with a boot order that
tries SD only (`BOOT_ORDER=0xf1`); USB mass-storage boot needs `0xf41` (read right to
left: SD, then USB, then loop). famdash now runs `0xf41`.

This step touches the **old, still-running** node, so it is a hand-off, and for pi-hole
a reboot interrupts DNS for the whole tailnet (it is the global nameserver): choose a
quiet moment.

1. User, on the old Pi (login user and sudo password per the old OS; on the old Pi OS
   node that is `natty`, who needs a sudo password). The Pi lacks the kitty terminfo, so
   `nano` aborts unless TERM is set first:
   ```bash
   ssh -t natty@<host> 'export TERM=xterm-256color; sudo -E rpi-eeprom-config --edit'
   ```
   Change the `BOOT_ORDER` line from `0xf1` to `0xf41`, save, exit.
2. User reboots the Pi (power/reboot is never the agent's); the EEPROM update is applied
   on that reboot. Reboot-test it **before** flashing: after it is back,
   `vcgencmd bootloader_config | grep BOOT_ORDER` should read `0xf41`.
3. Flash the stick via route A or B. Before first boot, remove the old SD card from the
   slot (SD is tried first) and never power old and new media together.
4. If the Pi shows no sign of life from the stick, suspect the boot order first, not the
   image: a Pi that cannot see the stick looks the same as a dead one.

## Replacing a dead card on a live Pi

No cutover: build (or reuse) an image of the host's current config, reuse the existing
key pair (`gen-host-key.sh <host> --show`; never regenerate, the age recipient in
`.sops.yaml` would no longer match), pass the Tailscale state if one was backed up, flash
via route A or B, and stop. A node that boots without its old `tailscaled.state` shows up
as a new tailnet device. If the image is older than the deployed generation, finish with
the `deploy-pi-host` skill.
