# Pi cutover runbook

The full, ordered cutover of one Raspberry Pi from its old media (Raspberry Pi OS)
to freshly flashed NixOS media, with the app's data carried across. SKILL.md
holds the short form; this file holds the exact commands, the done-rule for each
step, and what to do when a step fails. Placeholders: <host> (hosts.json key),
<ip> (its tailscale IP), <old-user> (the login that works on the OLD Pi OS node:
famdash had only `natty`; check the host's `notes` in `.claude/hosts.json`),
<unit>, <state-dir>, <owner> (the service's USER:GROUP on the new node),
<snap> (the local snapshot directory the pull step prints), <stamp>.

Every `sudo` below is a HAND-OFF: print the single command, the user runs it in
their own terminal (no `!` prefix, sudo has no TTY otherwise), and the skill
waits for the user to say it finished. The skill never runs sudo, flashes media,
power-cycles, reboots, or deletes anything on a Pi.

Paths: every script is given by absolute path, so the commands work from any directory.

## What a famdash-shaped run looks like (a record, for orientation)

- unit `famdash`, state dir `/var/lib/famdash` (one file, `db.json`), service owner
  `famdash:famdash`, endpoint `http://127.0.0.1:3000/`, sops secret `famdash-wifi-env`,
  link `wlan0` (Wi-Fi only), old login `natty`, new login `bosko`.
- The state directory is 0750 and owned by the service user, so the login user
  cannot read it: that is why steps 1 and 5 are root scripts the user runs.

The pi-hole run differs (DNS, Teleporter export, FTL): see dns-appliance.md. That
migration has not started.

## Step 0 - Preflight and the downtime window

1. Resolve the host (read-only):
   `bash -c 'source /home/bosko/NixOS/.claude/lib/pi-host.sh; pi_load <host> [<ip>]; echo "$PI_NAME $PI_IP $PI_USER $PI_ARCH $PI_BACKUP_DIR"'`
   (a Pi not in hosts.json yet needs the explicit ip).
2. Confirm the OLD node is really the old OS and reachable:
   `ssh -o BatchMode=yes <old-user>@<ip> 'grep ^ID= /etc/os-release'` must print
   `ID=debian` or `ID=raspbian`. `ID=nixos` means the host is already migrated:
   STOP, this skill is for the Pi OS to NixOS move; config updates to a NixOS Pi go
   through deploy-pi-host / fleet-rollout.
3. Confirm the NEW media is ready (built and flashed by pi-sd-flash; this skill
   does not flash): ask the user, and check without opening anything:
   - `ls $PI_BACKUP_DIR` shows the pre-generated host key's public half (`*.pub`)
     and, for an identity-preserving cutover, `tailscaled.state` (names and sizes
     only, never `cat` them);
   - `git grep -n <host> .sops.yaml` shows the host's age recipient (see
     new-host/references/sops-registration.md); no recipient = the new boot cannot
     decrypt secrets;
   - the user confirms the host private key and `tailscaled.state` are on the new
     media (pi-sd-flash puts them there).
4. If the new media is a USB stick: the Pi's EEPROM boot order must try USB. The
   old order was `0xf1` (SD only); USB needs `0xf41`. Read it on the old Pi
   (`vcgencmd bootloader_config | grep BOOT_ORDER`, or `sudo rpi-eeprom-config`);
   to change it the user runs `ssh -t <old-user>@<ip> 'export TERM=xterm-256color; sudo -E rpi-eeprom-config --edit'`
   (the Pi has no kitty terminfo, nano aborts without the TERM). The staged
   update is written to the OLD card's boot partition, so apply it (reboot on the
   old media, then re-read the boot order) BEFORE the swap. famdash runs `0xf41` (SD, then USB).
5. Decide the downtime window and fallback WITH THE USER via AskUserQuestion
   (shared stakes; never pick it yourself, even if a night-time slot looks
   obvious). Everything from the freeze (step 1) to a passing restore (step 5) is
   downtime: plan on 15 to 30 minutes plus the physical swap. A DNS appliance
   takes the household's DNS down: load dns-appliance.md first.
6. Check what the old node serves right now so there is something to compare
   against later: note the endpoint(s) and any counts the app shows (names and
   numbers only, never contents).

Done-rule: host resolved, old OS confirmed, new media confirmed ready, window and
fallback chosen by the user, and the user said go.

## Step 1 - Freeze and snapshot (hand-off)

1a. Stage the on-Pi script into the login user's home on the OLD Pi (an
    ordinary non-privileged file copy):
    `scp -o BatchMode=yes /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/on-pi/freeze-snapshot.sh <old-user>@<ip>:`
1b. Preview what it will do. This needs no root and changes nothing:
    `ssh -o BatchMode=yes <old-user>@<ip> bash freeze-snapshot.sh --dry-run --unit <unit> --state-dir <state-dir> --dest /home/<old-user>/<host>-snapshot --owner <old-user>`
    The `--dest` parent (the home dir) must already exist; `--dest` itself must not.
1c. HAND-OFF (one command, user's own terminal; they type the sudo password):
    `ssh -t <old-user>@<ip> sudo bash freeze-snapshot.sh --unit <unit> --state-dir <state-dir> --dest /home/<old-user>/<host>-snapshot --owner <old-user> --no-shutdown`
    `--no-shutdown` is deliberate: the Pi must stay up until step 2 passes. The
    script stops the unit (the service is DOWN from here on), copies the state with
    `cp -a`, writes `SHA256SUMS`, verifies the copy and the source, and chowns the
    snapshot to the login user. If it fails after stopping the unit it starts the
    unit again by itself. Use a relative script name, not `~/freeze-snapshot.sh`:
    your local zsh would expand the tilde to YOUR home before ssh sees it.
    Repeat `--unit` when the service has several units.
1d. Optional shortcut: `--shutdown-minutes 10` instead of `--no-shutdown` halts the
    Pi on its own 10 minutes later (cancel with `sudo shutdown -c`). It saves the
    step-3 hand-off but turns the "do not power down before the gate" rule into a
    race against a timer. Only use it if the user asks for the single-hand-off
    flow, and tell them the cancel command.
1e. While the OLD Pi is still up, keep its tailscale identity (the "Tailscale
    identity" section at the end). Skip only if the new media already carries it.

Done-rule: the user pasted (or confirmed) the line `OK: freeze-snapshot done.` and
the `snapshot: N files, B bytes` line.

## Step 2 - Pull and verify the snapshot (the gate)

`bash /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/pull-verify-snapshot.sh --host <host> --user <old-user> --remote-dir /home/<old-user>/<host>-snapshot`
(add `--ip <ip>` for a host not in hosts.json; `--dest DIR` to choose the local
directory, default `$PI_BACKUP_DIR/snapshot-<UTC stamp>`, 0700, outside the repo.)
It scp's the directory (BatchMode), then checks `SHA256SUMS` covers exactly the
files that arrived, `sha256sum -c`, and `jq empty` on every `*.json`. It prints the
file count, total bytes and per-file sha256, never contents. Note the printed
`pulled to: <snap>` path for steps 5 and 6.

- `GATE: PASS`: the Pi may be powered down. Go to step 3.
- `GATE: FAIL` (exit 1): do NOT power down. The service is still stopped, so
  restart it by hand-off:
  `ssh -t <old-user>@<ip> sudo systemctl start <unit>` (and `sudo shutdown -c` if
  a shutdown timer was set). Then ask the user (AskUserQuestion) whether to
  re-freeze and retry or to abandon the cutover. A scp or permission error usually
  means the wrong `--user` or a path typo; a hash mismatch means the copy broke
  or the unit was not really stopped: re-run the freeze into a new `--dest`.

Done-rule: `GATE: PASS` and a `pulled to:` path. Without it the old Pi stays on.

## Step 3 - Halt the old Pi and swap the media

1. HAND-OFF: `ssh -t <old-user>@<ip> sudo shutdown -h +1`
2. Wait until the Pi stops answering ping (3 misses in a row; a halted Pi 4's
   green LED keeps blinking, so the LED is not the signal, ping is):
   `bash -c 'miss=0; for i in $(seq 90); do if ping -c1 -W2 <ip> >/dev/null 2>&1; then miss=0; else miss=$((miss+1)); fi; [ $miss -ge 3 ] && { echo "Pi stopped answering"; exit 0; }; sleep 2; done; echo "still answering"; exit 1'`
3. Tell the user (physical, theirs to do): unplug power once ping has stopped
   (safe at that point), swap in the NEW media, keep the OLD media untouched and
   safe (it is the rollback), plug power back in.
   NEVER power the old and the new media at the same time: they share a tailscale
   identity and a MAC/IP.
4. Wait for the user to confirm it is powered on, then go to step 4.

Done-rule: ping stopped before the unplug, and the user confirmed the new media
is in and powered.

## Step 4 - Verify the new boot

`bash /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/verify-boot.sh --host <host> --expect-pubkey $PI_BACKUP_DIR/<hostkey>.pub --unit <unit> --url <endpoint> --secret <name> --link <dev>`
(repeat `--unit/--url/--secret/--link`; it waits up to 300 s for the Pi, the tailnet
comes up about 30 s after power-on; `--no-wait` for a single attempt.) Use the
public key file of the host key that was pre-generated for this Pi, found by
listing `$PI_BACKUP_DIR` (names only).

Read the verdict line by line (`PASS|WARN|FAIL|SKIP <check>: <detail>`, then
`RESULT: PASS|FAIL (n fail, n warn)`):

| Check | FAIL or WARN means | What to do |
| --- | --- | --- |
| ping | nothing answers on the tailscale IP | wait, then see "tailscale"; the old node's identity must have been copied |
| hostkey | the Pi presents a different ed25519 key than the pre-generated one | STOP. Not the Pi you flashed (or the wrong key on the card). Copy no data to it. Power it off, check the media, retry |
| known_hosts | an old entry for the IP/name differs (the old Pi OS key) | harmless for the checks (the session is pinned to the verified key) but ssh will refuse later: rerun with `--fix-known-hosts` (edits ~/.ssh/known_hosts, keeps `known_hosts.old`) or `ssh-keygen -R <ip>` |
| ssh | login refused | the new node takes keys from the flake; check the user (bosko) and that the key is declared |
| failed-units | a unit failed on boot | `ssh bosko@<ip> journalctl -u <unit> -b`; do not restore into a broken service |
| root-fs | the root partition is a fraction of the disk: expand-root-partition did not run (the nixpkgs unit breaks on util-linux 2.42 unless overridden, and only runs while `/nix-path-registration` exists, i.e. first boot) | HAND-OFF as root on the Pi: `echo ',+,' \| sfdisk -N2 --no-reread /dev/<disk>; partx -u /dev/<disk>; resize2fs /dev/<disk>p2` (the detail line prints the exact device names) |
| tailscale | tailscaled down or no address | the identity file was not on the media; see the Tailscale section. The Pi came up as a NEW node with a new IP |
| link:DEV | the link is not connected | wlan0/eth0 profile or credentials (sops secret) |
| journald | volatile logs | WARN only; the host config should set persistent storage |
| secret:NAME | /run/secrets/NAME missing | sops could not decrypt: the Pi's host key must match the age recipient in `.sops.yaml` (new-host/references/sops-registration.md) |
| unit / url | not active / not 2xx-3xx | journal as above; a fresh node has no data yet, an empty-state 200 is fine, a 5xx is not |

Done-rule: `RESULT: PASS` (every WARN read and understood). If it is FAIL, ask the
user via AskUserQuestion: fix forward (one named fix above) or roll back.

## Step 5 - Restore the data (stage, then hand-off)

1. Stage the snapshot and the restore script in the login home on the NEW Pi
   (ordinary file copies as the login user):
   `ssh -o BatchMode=yes bosko@<ip> mkdir -p <host>-restore`
   `scp -o BatchMode=yes -r <snap> bosko@<ip>:<host>-restore/snapshot`
   `scp -o BatchMode=yes /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/on-pi/restore-on-pi.sh bosko@<ip>:<host>-restore/`
2. Prove the copy survived the trip (silent on success; read-only):
   `ssh -o BatchMode=yes bosko@<ip> 'cd <host>-restore/snapshot && sha256sum --quiet -c SHA256SUMS'`
3. Preview (no root, changes nothing):
   `ssh -o BatchMode=yes bosko@<ip> bash <host>-restore/restore-on-pi.sh --dry-run --unit <unit> --state-dir <state-dir> --src <host>-restore/snapshot/<file> --owner <owner> --url <endpoint>`
4. HAND-OFF:
   `ssh -t bosko@<ip> sudo bash <host>-restore/restore-on-pi.sh --unit <unit> --state-dir <state-dir> --src <host>-restore/snapshot/<file> --owner <owner> --url <endpoint>`
   (`--src` takes several files; `--mode` defaults to 0600; the owner defaults to
   the state dir's owner.) It stops the unit, moves any existing file aside as
   `<file>.pre-restore-<stamp>`, installs the snapshot files, checks each hashes
   like its source, starts the unit, waits up to 30 s for `active`, and checks the
   URL. A failure while installing puts the originals back automatically; a
   failure after the start leaves the restored files and prints how to undo it.
   The state dir must exist: on a fresh Pi start the unit once first.

Done-rule: the user confirmed `OK: restore-on-pi done`, the unit reports
`active` and the URL answered 2xx/3xx.

## Step 6 - Compare against the live service

`bash /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/compare-snapshot.sh --snapshot <snap>/<file>.json --url <read-endpoint> --via bosko@<ip>`
(`--via` runs the curl on the Pi so a 127.0.0.1 URL works. When the app serves each
collection on its own endpoint instead of one whole document - FamDash serves
`/meals`, `/shopping`, `/notes`, `/recipes` - repeat
`--key-url <snapshot-key>=<endpoint>` in place of `--url`: only the listed top-level
keys are compared. `--live-file FILE` for
an API that needs a login: save its response to a private file first, never to
the repo; `--ignore-key K` for keys that legitimately move, such as timestamps.)
It prints `key  snapshot-count  live-count  MATCH|DIFF` per top-level key plus a
verdict, never values. Match is deep equality, so a changed value with the same
count is still a DIFF (its row shows short hashes so you can tell sides apart).
Choose the endpoint that returns the same document as the state file; if the app
has none, the byte-exact hash check in step 5 is the evidence and this step is
reported as SKIPPED, not as a pass.

Done-rule: `VERDICT: MATCH`, or each `DIFF` explained and accepted by the user.

## Step 7 - Done-rule and what to tell the user

The cutover is done when: gate passed (2), new boot passed (4), restore completed
(5) and the compare matched or was explained (6). Report with the format in
SKILL.md. Then say what the user still owns:
- the old media stays untouched as the rollback until they are satisfied (suggest
  a week, their call);
- cleanup on the Pis is theirs: the staged dirs (`~/freeze-snapshot.sh` and the
  `<host>-snapshot` dir on the old media; `<host>-restore` on the new Pi) and the
  `/tmp` copy of the tailscale state. Remote deletes are blocked for the agent, so
  hand each as one command: `ssh -t bosko@<ip> rm -r <host>-restore` (the snapshot
  also exists locally in `$PI_BACKUP_DIR`, which they should keep);
- update `.claude/hosts.json` notes and config changes through the normal flow
  (new-host / deploy-pi-host), not from this skill;
- the local snapshot lives in `$PI_BACKUP_DIR` (0700, outside the repo); never
  copy it into the repo.

## Rollback (any time before the user accepts the new boot)

Ask via AskUserQuestion: roll back, or fix forward? Never choose for them.

1. If the new node already took writes the user wants to keep (it has been in
   service more than a few minutes), snapshot it first: stage
   `freeze-snapshot.sh` on it and run the step-1 hand-off with its paths, then
   `pull-verify-snapshot.sh --host <host> --user bosko --remote-dir ...`. Otherwise
   anything written since the cutover is lost.
2. HAND-OFF: `ssh -t bosko@<ip> sudo shutdown -h +1`; wait for ping to stop
   (step 3's loop); the user unplugs power.
3. The user reinserts the OLD media and powers on. The old media was only
   touched by the staged script and the snapshot directory; the service state on
   it is exactly as it was at the freeze, and the unit starts normally at boot
   (`systemctl stop` does not persist). The old tailscale identity is back too.
4. Re-run `ssh -o BatchMode=yes <old-user>@<ip> true` and the app's endpoint to
   confirm the old setup serves again; stale known_hosts entries may need
   `ssh-keygen -R <ip>` again because the host key flipped back.
5. Never both media at once. Keep the failed new media aside for diagnosis.

## Tailscale identity (keep the node's name and IP)

The tailnet identity is one file, `/var/lib/tailscale/tailscaled.state` (0600,
root). Copying the OLD node's file onto the new media makes the new Pi come up as
the same tailnet device (same name, same 100.x address). Without it the new Pi
registers as a brand-new node with a different IP: `hosts.json` goes stale, and for
a nameserver (pi-hole) every tailnet device loses DNS. Do this while the OLD Pi
is still up (step 1e):

1. HAND-OFF (the old Pi OS login needs a sudo password, hence `ssh -t`):
   `ssh -t <old-user>@<ip> sudo install -m 600 -o <old-user> /var/lib/tailscale/tailscaled.state /tmp/tsstate`
2. Pull it into the private backup dir (the skill; BatchMode, mode 0600):
   `bash -c 'umask 077; mkdir -p "$HOME/pi-backups/<host>"; scp -o BatchMode=yes <old-user>@<ip>:/tmp/tsstate "$HOME/pi-backups/<host>/tailscaled.state"'`
   Never print or open it; `stat -c '%n %s %a'` is enough to confirm.
3. HAND-OFF (remote deletes are blocked for the agent): `ssh -t <old-user>@<ip> rm /tmp/tsstate`
4. Placing it on the new media at `/var/lib/tailscale/tailscaled.state` (mode 0600,
   root) is a flash-time step done with pi-sd-flash (root on this machine, hence a
   hand-off there). Confirm with the user that it is on the media before step 3.
5. Once the new node is up, `verify-boot.sh`'s tailscale check proves the address
   is back; `tailscale status` on another device should show the same node name,
   online, and the old node offline (never both online).
