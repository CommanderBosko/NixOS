# Pi cutover gotchas

Durable environment traps for this workflow. Each was hit for real or follows
directly from how these hosts are set up.

## Hand-offs, sudo and the classifier

- **No sudo from the skill, no TTY.** Anything needing sudo is a hand-off: print
  exactly one command, the user runs it in their own separate terminal (no `!`
  prefix; a `!` command also echoes into the transcript), and the skill waits for
  their confirmation. Never ask the user to type a secret into the session.
- **Remote deletes are blocked.** The auto-mode classifier refuses `rm -rf` and
  `shred` on other hosts, even for a temp file the skill itself created. Hand every
  remote cleanup (staged scripts, `/tmp/tsstate`, the snapshot dir on the old media)
  to the user as one command.
- **The old Pi OS node may only have `natty`, and `natty`'s sudo needs a password.**
  Use `ssh -t natty@<ip> sudo ...`; `-t` gives sudo a terminal for the prompt.
  `hosts.json` says `bosko@` for a host once it is NixOS; on the OLD node pass the
  working user with `--user` (pull-verify-snapshot.sh) and use it in every command.
  famdash's old node was `natty` only; check each host's `notes`.
- **Remote `ssh -t` quoting.** The remote shell re-parses the command line. Use
  absolute paths for state and destination, a relative script name (cwd is the
  login home) instead of `~/script.sh` (your zsh expands the tilde locally before
  ssh sees it), and single-quote anything with spaces, `$` or `;`. An empty
  positional argument can vanish across the hop.
- **bosko cannot read `/var/lib/<app>`** (the state dir is 0750 and owned by the
  service user). Any step touching the state needs a root script the user runs
  with sudo; the skill only stages the script and prints the command.

## Keys, identity and first boot

- **First boot reaches the tailnet about 30 s after power-on.** `verify-boot.sh`
  polls (every 5 s, 300 s by default); an immediate FAIL on ping is not a verdict.
- **The pre-generated host key must match `ssh-keyscan -t ed25519` of the new
  Pi.** A mismatch means this is not the Pi you flashed; stop and copy nothing to
  it. `--expect-pubkey` takes the PUBLIC file only and the script refuses a file
  that holds a private key.
- **Stale `known_hosts`.** The IP and name used to belong to the old Pi OS node, so
  ssh will refuse the new key ("REMOTE HOST IDENTIFICATION HAS CHANGED"). Fix with
  `ssh-keygen -R <ip>` and `ssh-keygen -R <name>`, or `--fix-known-hosts` (which only
  acts when a stale entry exists and the hostkey check did not fail).
- **Tailscale identity is a file copy.** The old node's `tailscaled.state` on the
  new media keeps name and IP. Never power the old and the new media together: two
  machines with one node key fight over it, and they share a MAC and LAN IP.
- **sops needs the host key first.** The new Pi decrypts secrets with the age key
  derived from its pre-generated ssh host key; that key must be in `.sops.yaml` and
  `sops updatekeys` must have run before the first boot, and the private key sits on
  the media's `/etc/ssh` (never in the Nix store or the repo). Without it every
  `--secret` check FAILs. See new-host/references/sops-registration.md.
- **USB boot needs the EEPROM boot order `0xf41`** (SD, then USB; the old value was
  `0xf1`). Change it with `sudo -E rpi-eeprom-config --edit` after `export
  TERM=xterm-256color` (no kitty terminfo on the Pi, nano aborts otherwise), and
  apply it by rebooting on the OLD media before the swap.

## Disk and image

- **expand-root-partition fails on nixpkgs sd-image** (util-linux 2.42 pads
  lsblk's MAJ:MIN column, sfdisk gets `'2  '`). The host config overrides the
  script; the unit only runs while `/nix-path-registration` exists (first boot), so
  the fix is untested at runtime for any new host and `verify-boot.sh` checks the
  result (root partition at least 90% of the disk). Manual fix on the Pi, as root:
  `echo ",+," | sfdisk -N2 --no-reread /dev/X; partx -u /dev/X; resize2fs /dev/XN2`.
- **A halted Pi 4's LED keeps blinking.** Ping is the signal: once the Pi has
  stopped answering, unplugging is safe.
- **nixos-anywhere is not an option on these Pis** (the Pi OS kernel lacks kexec,
  some are Wi-Fi only, and it would wipe the only card). The route is build the
  sdImage on gaming, flash spare media, swap. That is pi-sd-flash's job.
- **Never build on the Pi** (1 to 4 GB RAM). Config updates after the cutover go
  from gaming with `--target-host` (deploy-pi-host).

## Data hygiene

- **Keep app and family data out of the session.** Every script here prints
  counts, sizes, key names and hashes only. Do not `cat`, `head`, `jq .` or `Read`
  a snapshot, a `db.json`, a Teleporter zip or `tailscaled.state`; if a verdict
  looks wrong, ask the script for more counts, not the file for its contents.
- **Snapshots live in `$PI_BACKUP_DIR` (default ~/pi-backups/<host>/, 0700),
  outside the repo.** The repo is public. Nothing from there is ever copied into it.
- **A DIFF is not always a bug.** Timestamps, session counters and caches move
  between snapshot and live; use `--ignore-key` for those and say so in the report.

## Tooling traps on this machine

- `rg` is not installed: use the Grep tool or `grep -rIn`.
- `find` takes one predicate only (no `-o`, `-not`, `-exec`).
- In zsh, `echo ==` is an error (the `=` expansion); use `echo ---`.
- New files need `git add` before nix can see them (flake evaluation is
  git-tracked files only); not needed for these scripts, needed for host configs.
- The `ssh` alias for a host (ssh.nix) dials the tailscale IP; the LAN IP drifts
  with DHCP. Always use the tailscale IP.
