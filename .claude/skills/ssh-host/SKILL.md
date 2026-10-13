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

- **`<host>`** (optional) — the short host name to connect to: a key under `.hosts` in `/home/bosko/NixOS/.claude/hosts.json`, or one of that host's `.aliases`. If omitted, ask in Step 1.
- **`<command>`** (optional) — a single command to run on the host (e.g. "run `uptime` on gaming"). If omitted, the user wants an interactive shell. Step 3 handles the two cases differently.

## Known hosts — single source of truth

All host SSH targets and IPs live in `/home/bosko/NixOS/.claude/hosts.json`. **Never hardcode a copy here** — the resolver script below reads it live.

## Step 1 — Resolve the target

If the user provided a host name (e.g., `/ssh-host gaming`), run the resolver:

```bash
bash /home/bosko/NixOS/.claude/lib/resolve-host.sh <name>
```

It maps an alias to its host (each host's `.aliases` array in `hosts.json`) and looks up the SSH target there. On success (exit 0) it prints just the resolved SSH target — use it directly in Step 3. On failure (exit 1, no name given or not found) it prints the full host table (key, ssh, ip, notes) instead.

If no host was named, or the resolver failed, present the pick via the **AskUserQuestion tool**, populating its options from the table the script just printed (one option per known host) rather than asking in free-form prose. Skip the question if the user already named a host in their request.

## Step 2 — Show the command

Before running, print the exact SSH command so the user can see it:

```
Connecting to <host>:
  ssh <args>
```

## Step 3 — Run it

Use the `.ssh` value resolved from hosts.json directly — no extra IP or key flag needed.

**Interactive shell (no `<command>`) — hand off, don't run it via the Bash tool.** The Bash tool has no TTY, so an interactive `ssh` session can't run there. Print the exact command and ask the user to run it themselves (suggest the `!` prefix, or their own terminal for a long session):

```bash
! ssh <resolved .ssh>
```

**One-shot command — run it via the Bash tool**, quoting the remote command:

```bash
ssh <resolved .ssh> '<command>'
```

## Step 4 — Report the result

For a one-shot command, report its output and exit status (or the error if the connection was refused or timed out). For an interactive hand-off, wait for the user to say they're done, then report anything they paste back. No need to summarise what happened during the session.

---

## Key facts

- All local hosts have `AllowUsers bosko` (natalie-laptop also allows `natty`).
- All hosts have password auth disabled — key auth only.
- vpn-server is a NixOS host: log in as `bosko` (the Oracle `ubuntu` cloud-init user no longer accepts the key). `bosko` has passwordless sudo there.
- Hosts with a `tailscaleIp` (incl. pi-hole, famdash) get `~/.ssh/config` aliases dialling that stable Tailscale IP, generated from `.claude/hosts.json` by `dotfiles/common/configs/ssh.nix`; the LAN `.hosts.<name>.ip` is DHCP-drifting reference only.

## Scripts

- `.claude/lib/resolve-host.sh <name>` — maps an alias (`.hosts.<host>.aliases`) to its host and resolves the host to its SSH target from `hosts.json` (Step 1). Shared with the `/journal` skill. Exit 0 + SSH target on success; exit 1 + full host table on failure.
