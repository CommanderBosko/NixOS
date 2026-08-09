---
name: ssh-host
description: Use this skill when the user wants to "ssh into a host", "connect to gaming/laptop/server/vpn-server", "ssh to a machine", or "open a shell on X". Resolves short host names to the correct SSH command and runs it.
model: haiku
version: 0.2.0
---

# SSH to a Known Host

Connect to any host in the NixOS repo by short name, without needing to remember IPs, usernames, or key flags.

## Arguments

Parse from the user's request:

- **`<host>`** (optional) — the short host name to connect to (a key under `.hosts` in `/home/bosko/NixOS/.claude/hosts.json`). Aliases `natalie` → `natalie-laptop`, `vpn`/`oracle`/`server` → `vpn-server` are accepted. If omitted, ask in Step 1.

## Known hosts — single source of truth

All host SSH targets and IPs live in `/home/bosko/NixOS/.claude/hosts.json`. **Never hardcode a copy here** — the resolver script below reads it live.

## Step 1 — Resolve the target

If the user provided a host name (e.g., `/ssh-host gaming`), run the resolver:

```bash
bash /home/bosko/NixOS/.claude/lib/resolve-host.sh <name>
```

It normalizes aliases (`natalie` → `natalie-laptop`; `vpn`/`oracle`/`server` → `vpn-server`) and looks up the SSH target in `hosts.json`. On success (exit 0) it prints just the resolved SSH target — use it directly in Step 3. On failure (exit 1, no name given or not found) it prints the full host table (key, ssh, ip, notes) instead.

If no host was named, or the resolver failed, present the pick via the **AskUserQuestion tool**, populating its options from the table the script just printed (one option per known host) rather than asking in free-form prose. Skip the question if the user already named a host in their request.

## Step 2 — Show the command

Before running, print the exact SSH command that will be executed so the user can see it:

```
Connecting to <host>:
  ssh <args>
```

## Step 3 — Run it

Execute the command via the Bash tool with a generous timeout (600000ms), since this is an interactive SSH session.

Use the `.ssh` value resolved from hosts.json directly — no extra IP or key flag needed:
```bash
ssh <resolved .ssh>
```

## Step 4 — Report the result

After the session ends (or if the connection is refused/timed out), report the exit status briefly. No need to summarise what happened during the session.

---

## Key facts

- All local hosts have `AllowUsers bosko` (natalie-laptop also allows `natty`).
- All hosts have password auth disabled — key auth only.
- vpn-server is a NixOS host: log in as `bosko` (the Oracle `ubuntu` cloud-init user no longer accepts the key). `bosko` has passwordless sudo there.
- Local hosts use `~/.ssh/config` entries with static IPs (hostname resolution unreliable); the IPs are recorded per-host in `.claude/hosts.json` (`.hosts.<name>.ip`).

## Scripts

- `.claude/lib/resolve-host.sh <name>` — normalizes aliases and resolves a host name to its SSH target from `hosts.json` (Step 1). Shared with the `/journal` skill. Exit 0 + SSH target on success; exit 1 + full host table on failure.
