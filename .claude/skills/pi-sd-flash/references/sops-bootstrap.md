# sops bootstrap for a Pi: the pre-boot variant

Load this in Step 1 when `gen-host-key.sh <host> --check` says there is no key yet, or
`--show` says the recipient is not in `.sops.yaml`.

`new-host/references/sops-registration.md` describes the **post-first-boot** flow: boot
the machine, read its host key, derive the age recipient, rebuild. For a Pi flashed from
an image there is a cleaner order, because the host key can exist before the Pi does:

1. **Generate the key offline** (the agent may run this; it is unprivileged and
   offline):
   ```bash
   .claude/skills/pi-sd-flash/scripts/gen-host-key.sh <host>
   ```
   The pair lands in `$PI_BACKUP_DIR/ssh-host/` (default `~/pi-backups/<host>/ssh-host/`,
   directory 0700, private key 0600). The script prints only the public key, the age
   recipient and a `.sops.yaml` snippet; it refuses to overwrite an existing key.
2. **Register the recipient**: add the printed anchor under `keys:` in `.sops.yaml` and
   the alias to every rule the Pi must read (always `secrets/common.yaml`, for the login
   password hashes; plus `secrets/hosts/<host>.yaml` if the host has its own secret file,
   and `secrets/desktop.yaml` only for a desktop host, which a Pi is not). The real shape
   is in `.claude/skills/new-host/references/sops-registration.md`, step 2.
3. **Re-encrypt** every affected file with `sops updatekeys` (step 3 of the same file;
   it needs the admin age key on this machine). A new per-host secrets file or a new
   secret goes through the `add-secret` skill.
4. **`git add`** `.sops.yaml` and the re-encrypted files. A path flake only sees tracked
   files, so an untracked secrets file silently disappears from the build.
5. **Only now build the image.** The image embeds the encrypted files as they are at
   build time. Building before steps 2-4 produces an image whose `common.yaml` the Pi's
   key cannot decrypt: SSH key login still works, but the login password hashes and any
   host secret (e.g. famdash's Wi-Fi env file) fail to decrypt until a rebuild.
6. **Seed the private key onto the media** with `flash-pi-media.sh`: it installs
   `/etc/ssh/ssh_host_ed25519_key` (0600) and `.pub` (0644) on the new root partition.
   The private key never enters the repo, the Nix store or a chat, and the scripts only
   ever print the public side.

## Keeping the key

`~/pi-backups/<host>/ssh-host/` is the only copy of the private key besides the Pi's own
disk. Keep it for the life of the host and never copy its contents into the repo. If the
SD card is replaced later, reuse the same pair (`gen-host-key.sh <host> --show` confirms
it is there); generating a new one means a new age recipient and another
`sops updatekeys` round.

## Symptoms

- First boot shows sops decryption failures, or the password login does not work while
  key login does: the Pi is serving a different host key than the one registered. Compare
  `ssh-keyscan -t ed25519 <ip>` with the saved `.pub`; the usual cause is that the media
  was flashed without the key directory or from a stale card. `pi-cutover` owns the live
  diagnosis.
- `gen-host-key.sh` refuses: a key already exists. That is the point; use `--show`.
