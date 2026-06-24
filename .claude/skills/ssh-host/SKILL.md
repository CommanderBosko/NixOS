---
name: ssh-host
description: Use this skill when the user wants to "ssh into a host", "connect to gaming/laptop/server/vpn-server", "ssh to a machine", or "open a shell on X". Resolves short host names to the correct SSH command and runs it.
version: 0.1.0
---

# SSH to a Known Host

Connect to any host in the NixOS repo by short name, without needing to remember IPs, usernames, or key flags.

## Known hosts — single source of truth

All host SSH targets and IPs live in `/home/bosko/NixOS/.claude/hosts.json`. **Read that file; never hardcode a copy here.** List them with:

```bash
jq -r '.hosts | to_entries[] | "\(.key)\t\(.value.ssh)\t\(.value.ip // "-")\t\(.value.notes // "")"' /home/bosko/NixOS/.claude/hosts.json
```

## Step 1 — Resolve the target

If the user provided a host name (e.g., `/ssh-host gaming`), resolve its SSH target from hosts.json:

```bash
jq -r '.hosts["<name>"].ssh' /home/bosko/NixOS/.claude/hosts.json
```

Otherwise, list the hosts (command above) and ask which to connect to.

Accept these aliases before lookup:
- `natalie` → `natalie-laptop`
- `vpn` or `oracle` → `vpn-server`

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
