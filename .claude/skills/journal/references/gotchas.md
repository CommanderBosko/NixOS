# journal — Gotchas

- **`vpn-server` has no `~/.ssh/config` entry at all** — unlike `gaming`/`laptop`/`natalie-laptop`
  (which do), a bare `ssh bosko@vpn-server` or `ssh vpn-server` fails with "Could not resolve
  hostname" (observed 2026-08-07, mid vpn-server-reboot investigation). It's the one host that
  must always go through `scripts/journal.sh`'s `resolve-host.sh` lookup (or the raw IP from
  `.claude/hosts.json`) — never assume it resolves like the LAN hosts do.
