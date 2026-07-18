---
name: journal
description: Use this skill when the user wants to "check logs for X", "tail journal", "show logs", "journalctl X", or "debug service X". Tails journald logs for a named service, optionally on a remote host.
model: haiku
version: 0.1.0
---

# Journal Log Viewer

Fetch the last 50 lines of journald output for a named service, either locally or on a remote host.

## Arguments

Parse from the user's request:

- **`<service>`** (required) — the journald unit / service name, e.g. `sddm`, `wg-quick-wg0`, `nginx`, `bluetooth`. If absent, ask in Step 1.
- **`<host>`** (optional) — one of `gaming`, `laptop`, `natalie-laptop`, `vpn-server`. Default: the **local/current box** (no SSH). Remote targets are resolved from `.claude/hosts.json`.

## Step 1 — Resolve the service and host

If the user provided a service name (e.g. `/journal sddm`) use it directly. Otherwise ask:

> Which service do you want to check logs for? (e.g. `sddm`, `wg-quick-wg0`, `nginx`, `bluetooth`)

If the user mentioned a host (gaming/laptop/natalie-laptop/vpn-server), use that host. Otherwise default to **local** (the machine the user is on).

## Step 2 — Run journalctl

### Local (default)

```bash
journalctl -u <service> -n 50 --no-pager
```

### Remote hosts

Use SSH to run journalctl on the remote machine. Resolve the host's SSH target from the single source of truth, `.claude/hosts.json` (do not hardcode a copy):

```bash
jq -r '.hosts["<host>"].ssh' /home/bosko/NixOS/.claude/hosts.json
```

Remote command:

```bash
ssh <host-args> "journalctl -u <service> -n 50 --no-pager"
```

Example for gaming:

```bash
ssh bosko@gaming "journalctl -u sddm -n 50 --no-pager"
```

Use a 30-second timeout (30000ms) for remote commands.

## Step 3 — Present the output

Print the full log output. Then add a brief summary below:

- Note the **last timestamp** seen in the logs.
- If there are `error` or `failed` lines, highlight them explicitly — quote the relevant lines so the user sees the key failure immediately.
- If the service is not found or has no journal entries, say so clearly and suggest checking the service name with `systemctl list-units --all | grep <pattern>`.

## Step 4 — Offer follow-up

After showing logs, offer:

> Want to see more lines (`-n 200`), follow live output (`-f`), or check a different service?

Wait for the user to respond before running anything additional.

---

## Key facts

- Default host: local (wherever Claude Code is running — the gaming host in normal use).
- `--no-pager` is mandatory to get plain text output without interactive paging.
- NixOS's `networking.wg-quick.interfaces.wg0` generates a plain named unit, `wg-quick-wg0` — not an `@`-style template unit.
- vpn-server is a NixOS host — log in as `bosko` (not `ubuntu`).
- All local hosts use static IPs via `~/.ssh/config` — use hostnames, not raw IPs.
