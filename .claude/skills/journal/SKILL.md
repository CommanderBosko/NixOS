---
name: journal
description: Use this skill when the user wants to "check logs for X", "tail journal", "show logs", "journalctl X", or "debug service X". Tails journald logs for a named service, optionally on a remote host.
model: haiku
version: 0.1.0
---

# Journal Log Viewer

Fetch journald output for a named service (the last 50 lines by default), either locally or on a remote host.

## Arguments

Parse from the user's request:

- **`<service>`** (required) — the journald unit / service name, e.g. `sddm`, `wg-quick-wg0`, `nginx`, `bluetooth`. If absent, ask in Step 1.
- **`<host>`** (optional) — one of the flake hosts listed in `.claude/hosts.json`'s `.flakeHosts` (read the file, don't hardcode the list). Default: the **local/current box** (no SSH). Remote targets are resolved from `.claude/hosts.json`.
- **Line count** (optional) — e.g. "last 200 lines" → `-n 200`. Default 50.
- **Follow** (optional) — e.g. "follow", "tail -f", "watch live" → `-f`. Follows for a bounded window (60s default, `--for SECONDS` to change) and then stops on its own.

## Step 1 — Resolve the service and host

If the user provided a service name (e.g. `/journal sddm`) use it directly. Otherwise ask:

> Which service do you want to check logs for? (e.g. `sddm`, `wg-quick-wg0`, `nginx`, `bluetooth`)

If the user mentioned a host from `.flakeHosts`, use that host. Otherwise default to **local** (the machine the user is on).

## Step 2 — Run journalctl

Run the script — it handles both the local case and remote SSH dispatch (resolving the host's SSH target from `.claude/hosts.json` via the shared `resolve-host.sh`, with a 30s timeout):

```bash
bash /home/bosko/NixOS/.claude/skills/journal/scripts/journal.sh <service> [host] [-n N] [-f [--for SECONDS]]
```

Omit `[host]` for local. Add `-n N` / `-f` only if the user asked for them in the original request. In follow mode, set the Bash tool timeout above the follow window (the default 60s window fits the default 120000ms). If the named host can't be resolved, the script exits 1 and prints the known-hosts table instead of log output — fall back to the **AskUserQuestion tool** using that table rather than guessing a host name.

## Step 3 — Present the output

Print the full log output. Then add a brief summary below:

- Note the **last timestamp** seen in the logs.
- If there are `error` or `failed` lines, highlight them explicitly — quote the relevant lines so the user sees the key failure immediately.
- If the service is not found or has no journal entries, say so clearly and suggest checking the service name with `systemctl list-units --all | grep <pattern>`.

## Step 4 — Offer follow-up

After showing logs, present the follow-up choice via the **AskUserQuestion tool** rather than free-form prose, with options **More lines** (re-run the Step 2 script with `-n 200`), **Follow live** (re-run it with `-f`, which follows for 60s then stops), and **Different service** (restart at Step 1). Keep the same `[host]` for the first two. Wait for the user's pick before running anything additional.

---

## Key facts

- Default host: local (wherever Claude Code is running — the gaming host in normal use).
- `--no-pager` is mandatory to get plain text output without interactive paging.
- NixOS's `networking.wg-quick.interfaces.wg0` generates a plain named unit, `wg-quick-wg0` — not an `@`-style template unit.
- vpn-server is a NixOS host — log in as `bosko` (not `ubuntu`).
- All local hosts use static IPs via `~/.ssh/config` — use hostnames, not raw IPs.

## Gotchas

- **`vpn-server` has no `~/.ssh/config` alias** — always reach it through `scripts/journal.sh` (or the raw IP in `.claude/hosts.json`), never a bare `ssh vpn-server`. Details: `references/gotchas.md`.

## Scripts

- `scripts/journal.sh <service> [host] [-n N] [-f [--for SECONDS]]` — runs journalctl locally or over SSH (Steps 2 and 4). Default 50 lines; `-f` follows for a bounded window (60s default). Remote resolution shares `.claude/lib/resolve-host.sh` with the `/ssh-host` skill.
