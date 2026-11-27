# DNS appliance cutover (pi-hole and any host that is the nameserver)

> **Status: this is how the pi-hole cutover was planned and run on 2026-11-27.** The
> "As run" notes record what happened; a later nameserver host would follow the same shape.

Load this whenever the host is `pi-hole`, or `hosts.json`'s `notes` for it say it is
a nameserver (`jq -r '.hosts["<host>"].notes' .claude/hosts.json | grep -i -E 'nameserver|dns'`),
or the user says the Pi serves DNS.

## Why it is different

- **The cutover takes the household's DNS down.** The Xfinity gateway gives no admin access to
  its DHCP DNS, so devices do not get this Pi from DHCP. They reach it through its Tailscale
  IP: NixOS hosts point straight at `tailscaleIp` (with a 1.1.1.1 fallback, a few
  seconds slower per lookup), and every other tailnet device (phones, TVs) uses the
  tailnet global nameserver set in the Tailscale admin console. A LAN-only device that
  uses the gateway's own DNS is not affected.
- **It is the tailnet's global nameserver (100.92.242.60).** That IP is its tailscale
  identity: lose the identity and the address changes under every device (see the
  identity section of the runbook; here it is mandatory, not optional).
- **Same Pi, same MAC.** The LAN address is static in the NixOS config (`ip` in
  hosts.json is authoritative), so no DHCP lease matters.
- The board is a Pi 4B with 1 GB of RAM and Ethernet only. The NIC is `end0` on NixOS
  (Pi OS called it `eth0`). Never build on it.

## First step, before anything stops: the window and the fallback

Ask via AskUserQuestion; never choose for the user, and do not infer a "quiet"
slot yourself. Put these decisions in front of them:

1. **The window**: when it may be down, and how long they will tolerate (plan about 30
   to 45 minutes including the card swap; longer if anything fails).
2. **The fallback while it is down.** On this network the only lever is the tailnet
   global nameserver (Tailscale admin console DNS page, or the Tailscale MCP): point it
   at 1.1.1.1 for the window and put `100.92.242.60` back afterwards. There is no router
   step: the Xfinity gateway gives no admin access. Setting it through the MCP's `set_nameservers` drops the
   nameserver's "Use with exit node" flag: re-tick it in the console if you rely on it.
3. **Who is affected right now** (anyone relying on it for work, video calls,
   the TV): the user knows, you do not.
4. **The abort criterion**: when to roll back (suggest: the new boot has not
   resolved a test query within 30 minutes of power-on) and that rollback is
   re-flashing the old media image.

Do not start step 1 of the runbook until all four are answered.

*As run:* now, fallback = tailnet nameserver to 1.1.1.1 (set by Hermes), nobody affected,
abort at 30 minutes. The new Pi answered DNS about 4 minutes after power-on.

## Before the freeze: backups (existence only, never open them)

The pre-migration backups belong in `~/pi-backups/pi-hole/` (0700, outside the
repo): the Teleporter export (`sudo pihole-FTL --teleporter` on the Pi, run from /tmp,
then scp it and delete the Pi copy), `pihole-updatelists.conf`, and the `unbound.conf.d`
directory. They contain configuration and password material: do not read, print or
attach them. Check they exist with `stat -c '%n %s %a' ~/pi-backups/pi-hole/*`.

When the new media is flashed over the SAME card (no spare), the card itself is the only
other copy: take a live image first and verify it, e.g.
`ssh pi-hole 'sudo -n ionice -c3 dd if=/dev/mmcblk0 bs=4M status=none' | zstd -T4 -3 -o ~/pi-backups/pi-hole/old-card.img.zst`,
then `zstd -tq` it and check that the decompressed byte count equals the device size
(`lsblk -bdno SIZE /dev/mmcblk0`). About 15 minutes and 2.4 GB for a 32 GB card.
Rolling back means flashing that image onto the card (`zstd -dc | dd`, a hand-off).

Record a "before" for the comparison, as counts only (the `pihole-api` skill prints raw
JSON, so redirect it to a private file): the block list count (`GET /api/lists?type=block`)
and the number of clients and groups (from the Teleporter `gravity.db` read-only).

## What the freeze and the restore mean here

- **A declarative host has nothing to restore.** On NixOS the lists are in Nix
  (`hosts/pi-hole/adlists.nix`), groups and clients are applied by `pihole-clients.service`
  from a sops secret (build the JSON with `hosts/pi-hole/extract-clients.sh` from the
  Teleporter zip), and the query history starts fresh by the user's choice. So the generic
  freeze, pull-and-verify, restore and compare steps (runbook steps 1, 2, 5 and 6) were
  skipped; the Teleporter export plus the card image are the safety net.
- Unit names differ by OS: `pihole-FTL.service` on Pi OS, `pihole-ftl.service` on NixOS.
- If a restore of plain files is ever needed, `restore-on-pi.sh` installs them with their
  own `--owner` and `--mode`. A Teleporter import is not needed.

## The downtime clock

DNS is down from the moment the old Pi halts until the new node answers. Do every
read-only preparation first (hosts.json, backups, the card image, the built image
staged on the flashing machine and checked), then do the halt, the swap and the flash back
to back. If the new boot fails its hostkey or tailscale check, the fastest recovery is
to reflash the old image, not debugging in place.

## Post-cutover checks (read-only)

1. `verify-boot.sh --host pi-hole --expect-pubkey <pub> --unit pihole-ftl.service --unit unbound.service --url http://127.0.0.1/ --secret pihole-web-env --secret pihole-clients --fix-known-hosts`
   (the web root answers 302; the NIC is `end0`). `--fix-known-hosts` removes the stale Pi OS
   host key; the next plain `ssh` then needs `-o StrictHostKeyChecking=accept-new` once (the
   key was verified against the pre-generated one).
2. Resolve through the new node, both addresses, from another machine:
   `dig +short @100.92.242.60 example.com` (tailnet) and `@<LAN ip>`. No `dig`: `nix shell
   nixpkgs#dnsutils -c dig ...`. Test a name on a block list (`doubleclick.net`) and expect
   `0.0.0.0` (blocking mode NULL). **Gravity reruns at every FTL start (and the weekly timer
   fires at boot, because the clock jumps on a Pi without an RTC), so a block only answers
   after about a minute.**
3. On the Pi, `systemctl status pihole-clients pihole-gravity` shows the clients unit ran
   ("N declared, N created, 0 failed") and gravity finished (domain count). Counts only:
   never print client names or MACs.
4. Compare against the "before" counts: enabled lists (the declared list is the old enabled
   set minus anything dropped on purpose), clients and groups.
5. On a tailnet device, `tailscale status` shows the node under its old name and
   100.92.242.60. A new name or IP means the identity was not preserved: the global
   nameserver must be changed in the admin console and `hosts.json` updated.
6. Put the fallback back (tailnet nameserver to `100.92.242.60`) only after step 2 passes
   from a tailnet client; check the admin console afterwards.

## After

- Keep the old media (or its image) untouched until the user is sure; with DNS, give it
  more than a day of normal household use.
- Config changes later go through `deploy-pi-host` (pi-hole is excluded from `fleet-rollout`
  by its `fleetExclude`); API calls stay with the `pihole-api` skill; single-unit sweeps with
  `verify-service`.
