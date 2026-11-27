# DNS appliance cutover (pi-hole and any host that is the nameserver)

> **Status: the pi-hole migration has NOT started. This file is a plan, not a
> record.** Nothing below has been run against the pi-hole Pi. Unit names, state
> paths and API calls are the expected ones; confirm each against the live node
> before relying on it. famdash (a dashboard, no DNS role) is the only Pi that
> has been migrated.

Load this whenever the host is `pi-hole`, or `hosts.json`'s `notes` for it say it is
a nameserver (`jq -r '.hosts["<host>"].notes' .claude/hosts.json | grep -i -E 'nameserver|dns'`),
or the user says the Pi serves DNS.

## Why it is different

- **The cutover takes the whole household's DNS down.** LAN clients resolve through
  this Pi (`ip` in hosts.json, currently 10.0.0.19, DHCP-assigned and not
  reserved at the router).
- **It is also the tailnet's global nameserver (100.92.242.60).** Every device on
  the tailnet, phones and laptops included, loses DNS while it is down. NixOS
  desktop hosts keep a 1.1.1.1 fallback (shared networking module); other devices
  may not. That IP is its tailscale identity: lose the identity and the
  nameserver address changes under every device (see the identity section of the
  runbook; here it is mandatory, not optional).
- **Same Pi, same MAC, same LAN IP.** Swapping media in the same board keeps the
  DHCP lease. Flashing a different Pi changes the MAC and so the LAN IP that
  clients and the router point at.
- The board is a Pi 4B with 1 GB of RAM and Ethernet only: expect a slow first
  boot and no Wi-Fi link to check; use `--link eth0`. Never build on it.

## First step, before anything stops: the window and the fallback

Ask via AskUserQuestion; never choose for the user, and do not infer a "quiet"
slot yourself. Put these decisions in front of them:

1. **The window**: when it may be down, and how long they will tolerate (plan 15
   to 30 minutes plus the swap; longer if anything fails).
2. **The fallback while it is down**, for example: switch the router's DHCP DNS and
   the tailnet global nameserver (Tailscale admin console) to a public resolver
   for the window and put them back afterwards; or accept the outage in an
   off-hours slot; or have a second resolver already running. These are the
   user's actions on the router and the admin console, the skill cannot do them.
3. **Who is affected right now** (anyone relying on it for work, video calls,
   the TV): the user knows, you do not.
4. **The abort criterion**: when to roll back (suggest: the new boot has not
   resolved a test query within the window) and that rollback is the old media.

Do not start step 1 of the runbook until all four are answered.

## Before the freeze: backups (existence only, never open them)

The pre-migration backups belong in `~/pi-backups/pi-hole/` (0700, outside the
repo): the Teleporter export (a `.zip` with the whole configuration: lists,
groups, clients, settings), `pihole-updatelists.conf`, and the `unbound.conf.d`
directory (the resolver settings). They contain the configuration, the API
settings and password material: do not read, print or attach them.

Check they exist and are non-trivial with names, sizes and modes only:
`stat -c '%n %s %a' ~/pi-backups/pi-hole/*` and `ls -l ~/pi-backups/pi-hole/unbound.conf.d`.
If any is missing, make it before the window opens, not during. Take the
Teleporter export through the pi-hole web UI (or its API) and save it into that
directory; the skill only checks that it landed.

Also record a "before" for the comparison, as counts: save the block list API
response to a private file (the pihole-api skill prints raw JSON to stdout, so
redirect it, do not let it into the session):
`bash -c 'umask 077; bash /home/bosko/NixOS/.claude/skills/pihole-api/scripts/pihole-api.sh GET "/api/lists?type=block" > "$HOME/pi-backups/pi-hole/lists-before.json"'`

## What the freeze and the restore mean here

- The freeze script is generic. For pi-hole the useful ones are: `--unit pihole-FTL.service`
  (add `--unit unbound.service` if unbound runs on this Pi) and `--state-dir /etc/pihole`.
  Check the real paths on the node first (`/etc/pihole`, `/etc/dnsmasq.d`,
  `/etc/unbound/unbound.conf.d` vary by install). The snapshot is a safety net;
  the Teleporter export is the portable form of the settings.
- **Restore is a Teleporter import, not a file copy** of the FTL database. Import
  the Teleporter zip through the pi-hole web UI or API on the new node (the zip is
  the restore artifact; `restore-on-pi.sh` is for plain files such as
  `pihole-updatelists.conf` or unbound snippets, installed with their own
  `--owner` and `--mode`). The exact Teleporter import call is unverified on this
  version: check the pi-hole docs for the installed release.
- After the import the gravity database may need a rebuild. The pihole-api skill
  does this with `sudo -n pihole -g` over ssh; the NixOS node has no passwordless
  sudo, so that becomes a hand-off: `ssh -t bosko@<ip> sudo pihole -g`.
- **Open concern:** `pihole-api.sh` authenticates by reading the CLI password with
  `sudo -n cat /etc/pihole/cli_pw`, which needs passwordless sudo. On the NixOS
  host that will fail unless the host config exposes the API password another way
  (for example a sops secret). Decide that in the host configuration before the
  cutover, or the post-cutover API checks below cannot run unattended.

## The downtime clock

DNS is down from the moment the unit stops (runbook step 1) until the new node
answers (this file's checks). To keep it short: do every read-only preparation
first (hosts.json, backups, the dry-run previews, the media check), run the
freeze and the pull back to back, and do not start the physical swap until the
gate has passed. If the new boot fails its hostkey or tailscale check, the
fastest recovery is rollback to the old media (about the time of a Pi boot), not
debugging in place.

## Post-cutover checks (read-only)

1. `verify-boot.sh --host pi-hole --expect-pubkey <pub> --unit pihole-FTL.service --link eth0 --secret <name>`
   (add `--url` for the local admin endpoint on the node, for example `http://127.0.0.1/admin/`;
   confirm the real path on the node).
2. Resolve through the new node from another machine, both addresses:
   `dig +short @100.92.242.60 example.com` (tailnet) and `dig +short @<LAN ip> example.com`.
   No `dig`: `nix shell nixpkgs#dnsutils -c dig ...` (or `getent hosts` against a
   resolver you configured). Test a name known to be on a block list and expect
   the configured blocking answer (`0.0.0.0` or `NXDOMAIN` depending on the blocking mode).
3. API comparison (pihole-api skill, output to a private file, then count-only):
   `bash -c 'umask 077; bash /home/bosko/NixOS/.claude/skills/pihole-api/scripts/pihole-api.sh GET "/api/lists?type=block" > "$HOME/pi-backups/pi-hole/lists-after.json"'`
   `bash /home/bosko/NixOS/.claude/skills/pi-cutover/scripts/compare-snapshot.sh --snapshot "$HOME/pi-backups/pi-hole/lists-before.json" --live-file "$HOME/pi-backups/pi-hole/lists-after.json"`
   Expect `lists` to MATCH in count and content; use `--ignore-key` for fields that
   move, such as last-update timestamps and gravity counters, and say so.
4. On a tailnet device, `tailscale status` shows the node online under its
   old name and 100.92.242.60. If it shows a new name or IP, the identity was not
   preserved: the global nameserver must be changed in the Tailscale admin console
   (the user's action) and `hosts.json` updated.
5. Put the fallback back (router DHCP DNS, tailnet nameserver) only after step 2
   passes from a LAN client and a tailnet client; the user does that.

## After

- Keep the old media untouched until the user is sure; with DNS, give it more
  than a day of normal household use.
- Config changes later go through deploy-pi-host / fleet-rollout once pi-hole is a
  flake host; API poking stays with the pihole-api skill; single-unit sweeps with
  verify-service.
