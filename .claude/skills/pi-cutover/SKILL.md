---
name: pi-cutover
description: Move a running Raspberry Pi's service from its old media to freshly flashed NixOS media with its app data intact: freeze and snapshot, swap the media, verify the new boot, restore the data, compare, and roll back if needed. Use when the user says "cut over the pi", "swap the pi to nixos", "pi cutover", "migrate the pi data", "verify the new pi boot", "restore pi data", "roll back the pi".
version: 0.1.0
---

# Pi Cutover

Carry one Raspberry Pi's service from its old media (Pi OS) to freshly flashed NixOS media with the app's data intact: freeze and snapshot, swap, verify the boot, restore, compare, and roll back if needed. (Bucket: Orchestration)

This skill runs ONE job. It is not: building or flashing the media (use **pi-sd-flash**), later config updates to a NixOS Pi (**deploy-pi-host** / **fleet-rollout**), pi-hole API calls (**pihole-api**), a single-unit health sweep on a flake host (**verify-service**), or scaffolding the host config (**new-host**, **add-secret**).

## Arguments

Parse from the user's request; ask for what is missing (AskUserQuestion, recommended value first; free text via Other):

- **host** (required): a `.claude/hosts.json` key or alias (`famdash`, `pi-hole`), or any name plus **ip** (the tailscale IP) for a Pi not registered yet. Nothing is hardcoded per Pi: name, IP and arch come from hosts.json through `.claude/lib/pi-host.sh`.
- **old login user**: the user that works on the OLD Pi OS node (often `natty`, not `bosko`; see the host's `notes`).
- **the app**: its systemd **unit(s)**, **state dir**, the service's **owner** (`USER:GROUP` on the new node), which **state files** to restore, and the **endpoint(s)** that prove it works (famdash was: unit `famdash`, state `/var/lib/famdash/db.json`, owner `famdash:famdash`, `http://127.0.0.1:3000/`).
- **checks for the new boot**: sops **secret** names, **link** devices (`wlan0` / `eth0`) and the **public key file** of the pre-generated host key (in `$PI_BACKUP_DIR`).

Backups and snapshots live in `$PI_BACKUP_DIR` (default `~/pi-backups/<host>/`, 0700, outside the repo). The repo is public: never copy anything from there into it.

## Steps

**Hand-off rule (applies to every sudo, power, flash or remote-delete step):** the skill never runs privileged or physical steps. Print exactly ONE command in a fenced block, tell the user to run it in their own separate terminal (no `!` prefix: sudo has no TTY otherwise), then stop and wait for their confirmation. Remote `rm` / `shred` on other hosts are blocked, so cleanup is a hand-off too. Every script prints counts, names and hashes only: never open, `cat` or paste snapshot data, a `db.json`, a Teleporter zip or `tailscaled.state`.

Exact commands, done-rules and failure triage for each step: `references/runbook.md` (load it before Step 1). Script paths below are absolute on purpose.

0. **Preflight and the downtime window.** Resolve the host (`bash -c 'source /home/bosko/NixOS/.claude/lib/pi-host.sh; pi_load <host> [ip]; echo "$PI_NAME $PI_IP $PI_USER $PI_BACKUP_DIR"'`). Confirm the OLD node runs Pi OS (`ssh -o BatchMode=yes <old-user>@<ip> 'grep ^ID= /etc/os-release'`; `ID=nixos` means STOP, it is already migrated). Confirm with the user that the new media is flashed (pi-sd-flash) and carries the pre-generated host key and the old tailscale identity; for a USB stick, that the EEPROM boot order is `0xf41`. **If the host is a DNS appliance (`pi-hole`, or hosts.json notes say nameserver/DNS), load `references/dns-appliance.md` first: the cutover takes the WHOLE household's DNS down.** Then ask via **AskUserQuestion** for the downtime window and the fallback while it is down. This is a shared-stakes decision: never pick the window yourself, not even a "quiet" night slot. Done when the user has chosen the window and fallback and said go.
1. **Freeze and snapshot (hand-off).** Stage the on-Pi script: `scp -o BatchMode=yes /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/on-pi/freeze-snapshot.sh <old-user>@<ip>:`. Preview it without root: `ssh -o BatchMode=yes <old-user>@<ip> bash freeze-snapshot.sh --dry-run --unit <unit> --state-dir <dir> --dest /home/<old-user>/<host>-snapshot --owner <old-user>`. Then hand off the single command `ssh -t <old-user>@<ip> sudo bash freeze-snapshot.sh --unit <unit> --state-dir <dir> --dest /home/<old-user>/<host>-snapshot --owner <old-user> --no-shutdown` (the service is DOWN from here on; `--no-shutdown` keeps the Pi up until the gate passes). While the old Pi is still up, keep its tailscale identity (runbook, "Tailscale identity"). Done when the user confirms `OK: freeze-snapshot done.`
2. **Pull and verify the snapshot (the gate).** `bash /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/pull-verify-snapshot.sh --host <host> --user <old-user> --remote-dir /home/<old-user>/<host>-snapshot`. Only `GATE: PASS` lets the Pi be powered down. On `GATE: FAIL`: do not power down; the unit is still stopped, so hand off `ssh -t <old-user>@<ip> sudo systemctl start <unit>` and ask (AskUserQuestion) whether to re-freeze and retry or abandon. Note the `pulled to:` path.
3. **Halt the old Pi and swap the media.** Hand off `ssh -t <old-user>@<ip> sudo shutdown -h +1`. Poll until the Pi stops answering ping (a halted Pi 4's LED keeps blinking; ping is the signal; runbook step 3 has the loop). Tell the user: unplug power once ping has stopped, put the NEW media in, keep the OLD media untouched (it is the rollback), power on. NEVER power both media at once. Wait for the user's confirmation.
4. **Verify the new boot.** `bash /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/verify-boot.sh --host <host> --expect-pubkey <pub file> --unit <unit> --url <endpoint> --secret <name> --link <dev>` (waits up to 300 s; the tailnet comes up about 30 s after power-on). Read every `PASS|WARN|FAIL|SKIP` line. A `hostkey` FAIL means this is not the Pi you flashed: stop, restore nothing to it. A `root-fs` FAIL has the manual sfdisk/partx/resize2fs fix in its detail (hand-off, root). Stale known_hosts is a WARN with `ssh-keygen -R`; `--fix-known-hosts` applies it. Done on `RESULT: PASS`. On FAIL ask the user: fix forward or roll back (runbook, "Rollback").
5. **Restore the data (stage, then hand-off).** Stage `<snap>` and `/home/bosko/NixOS/.claude/skills/pi-cutover/scripts/on-pi/restore-on-pi.sh` to `~/<host>-restore/` on the new Pi (mkdir it, then scp, BatchMode, as `bosko`; exact commands in the runbook), prove the copy with `ssh bosko@<ip> 'cd <host>-restore/snapshot && sha256sum --quiet -c SHA256SUMS'`, preview with `--dry-run`, then hand off `ssh -t bosko@<ip> sudo bash <host>-restore/restore-on-pi.sh --unit <unit> --state-dir <dir> --src <host>-restore/snapshot/<file> --owner <owner> --url <endpoint>`. Done when the user confirms `OK: restore-on-pi done` (unit active, URL 2xx/3xx).
6. **Compare against the live service.** `bash /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/compare-snapshot.sh --snapshot <snap>/<file>.json --url <read endpoint> --via bosko@<ip>` (an API that serves each collection on its own endpoint, like FamDash's `/meals` and `/notes`: repeat `--key-url <key>=<endpoint>` instead of `--url`; `--live-file` for an API that needs a login; `--ignore-key K` for timestamps). Per-key counts and MATCH/DIFF only, never values. Done on `VERDICT: MATCH` or each DIFF explained and accepted by the user. If the app has no read endpoint, say the compare was skipped; the step 5 hash check is then the evidence.
7. **Decide and close out.** If anything is still wrong, ask via **AskUserQuestion**: roll back (power the new node off, reinsert the old media, never both) or fix forward; never decide for them (runbook, "Rollback"). If it is good, tell the user the old media stays untouched as the rollback until they are satisfied, and hand off the cleanup (staged dirs on both Pis, the `/tmp` tailscale-state copy).
8. **Report** in this shape:
   ```
   pi-cutover: <host> (<ip>)   window: <what the user chose>
   snapshot : PASS|FAIL  <N> files, <B> bytes  at <snap>
   new boot : PASS|FAIL  (<n> fail, <n> warn)  <warnings in words>
   restore  : done|failed  <unit> active, <url> HTTP <code>
   compare  : MATCH|DIFF|SKIPPED  <keys compared, ignored keys and why>
   old media: untouched, kept as the rollback  | rolled back to it
   you still: <hand-offs the user owes: cleanup of ~/freeze-snapshot.sh, <host>-snapshot, <host>-restore, /tmp/tsstate;
              fallback undone (router/tailnet DNS) for a DNS host; hosts.json / config via new-host or deploy-pi-host;
              how long to keep the old media>
   ```

## Gotchas

- **Never both media powered at once**: one tailscale identity, one MAC, one LAN IP. The old media is untouched and is the rollback.
- **The gate is mandatory.** `freeze-snapshot.sh` is run with `--no-shutdown` so the Pi stays up until `pull-verify-snapshot.sh` prints `GATE: PASS`. The service is already stopped by then, so a failed gate needs the unit started again (hand-off).
- **bosko cannot read `/var/lib/<app>`** (0750, service user). State steps are root scripts the user runs with sudo; the skill only stages them. The old Pi OS login may be `natty` (sudo needs a password; `ssh -t` and `--user`).
- **A stale `known_hosts` entry** for the IP/name blocks plain ssh after the swap (`ssh-keygen -R` or `--fix-known-hosts`); verify-boot pins its own session to the verified key, so it still works.
- **The root partition may not expand** on first boot (nixpkgs sd-image bug with util-linux 2.42; the host config overrides the script but it is untested at runtime). verify-boot checks it and prints the manual fix.
- **Use the tailscale IP**, never the drifting LAN IP, and the relative script name (not `~/x.sh`) in `ssh -t` commands: zsh expands the tilde locally.
- More traps (classifier blocks remote deletes, zsh `echo ==`, EEPROM boot order, sops key first): `references/gotchas.md`.

## Scripts

All under `.claude/skills/pi-cutover/scripts/` (repo-root-relative; call them by absolute path, a bare `scripts/...` path 404s from the Bash tool's cwd). Each has `--help` and exit codes 0 ok, 1 check failed or refused, 2 usage error. The two `on-pi/` scripts are self-contained and run as root ON a Pi; this skill only stages them.

- `.claude/skills/pi-cutover/scripts/on-pi/freeze-snapshot.sh --unit U --state-dir D --dest DIR [--owner USER] [--no-shutdown] [--shutdown-minutes N] [--dry-run]`: stop the unit, `cp -a` the state, write and verify `SHA256SUMS`, chown to the login user, optionally schedule power-off; restarts the unit if it fails. Staged and handed off in Step 1.
- `.claude/skills/pi-cutover/scripts/pull-verify-snapshot.sh --host H [--ip IP] [--user U] --remote-dir DIR [--dest DIR] | --local-src DIR`: scp the snapshot into `$PI_BACKUP_DIR`, check sums, file set and JSON validity; prints `GATE: PASS|FAIL`. Step 2.
- `.claude/skills/pi-cutover/scripts/verify-boot.sh --host H [--ip IP] [--expect-pubkey FILE] [--wait N | --no-wait] [--unit U]... [--url URL]... [--secret NAME]... [--link DEV]... [--fix-known-hosts]`: read-only boot verification, `PASS|WARN|FAIL|SKIP` lines and `RESULT`. Step 4.
- `.claude/skills/pi-cutover/scripts/on-pi/restore-on-pi.sh --unit U --state-dir D --src FILE... [--owner USER:GROUP] [--mode 0600] [--url URL] [--wait N] [--dry-run]`: stop, move existing files aside, install the snapshot files, start, wait for active, check the URL; rolls back if the install fails. Staged and handed off in Step 5.
- `.claude/skills/pi-cutover/scripts/compare-snapshot.sh --snapshot FILE (--url URL [--via SSH_TARGET] | --key-url KEY=URL... [--via SSH_TARGET] | --live-file FILE) [--ignore-key K]...`: per-top-level-key counts and MATCH/DIFF, no values. Step 6.
- Tests (no network, PATH shims): `bash <script>.test.sh` next to each script above (for example `bash /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/verify-boot.test.sh`). Run them after editing a script.

## References

- `references/runbook.md`: the full ordered cutover with exact commands, a done-rule per step, the verify-boot triage table, rollback, and the tailscale-identity flow. Load it before Step 1 of any real cutover.
- `references/gotchas.md`: durable environment traps (hand-offs and the classifier, natty sudo, known_hosts, first boot, sops key order, EEPROM boot order, expand-root-partition, data hygiene, tooling traps). Load it when a step misbehaves or before writing a hand-off.
- `references/dns-appliance.md`: extra care for pi-hole or any nameserver host (household and tailnet DNS outage, window and fallback questions, Teleporter backups, post-cutover checks). Written for the pi-hole cutover (done 2026-11-27) and corrected with what really happened. Load it in Step 0 whenever the host serves DNS.
