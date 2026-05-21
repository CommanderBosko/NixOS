---
name: ssh-host
description: Use this skill when the user wants to "ssh into a host", "connect to gaming/laptop/server/vpn-server", "ssh to a machine", or "open a shell on X". Resolves short host names to the correct SSH command and runs it.
version: 0.1.0
---

# SSH to a Known Host

Connect to any host in the NixOS repo by short name, without needing to remember IPs, usernames, or key flags.

## Known hosts

| Short name      | SSH command                                                   | Notes                        |
|-----------------|---------------------------------------------------------------|------------------------------|
| `gaming`        | `ssh bosko@gaming`                                            | Local, IP: 10.0.0.251        |
| `laptop`        | `ssh bosko@laptop`                                            | Local, IP: 10.0.0.227        |
| `natalie-laptop`| `ssh bosko@natalie-laptop`                                    | Local, IP: 10.0.0.103        |
| `server`        | `ssh bosko@nixos-server`                                      | Local, hostname is nixos-server |
| `pi-hole`       | `ssh bosko@pi-hole`                                           | Local, IP: 10.0.0.20           |
| `vpn-server`    | `ssh -i ~/.ssh/id_ed25519 ubuntu@150.136.232.63`              | Oracle Cloud ARM VM          |

## Step 1 — Resolve the target

If the user provided a host name as an argument (e.g., `/ssh-host gaming`), use it directly. Otherwise, present the table above and ask which host to connect to.

Accept these aliases:
- `gaming` → `ssh bosko@gaming`
- `laptop` → `ssh bosko@laptop`
- `natalie-laptop` or `natalie` → `ssh bosko@natalie-laptop`
- `server` or `nixos-server` → `ssh bosko@nixos-server`
- `pi-hole` → `ssh bosko@pi-hole`
- `vpn-server` or `vpn` or `oracle` → `ssh -i ~/.ssh/id_ed25519 ubuntu@150.136.232.63`

## Step 2 — Show the command

Before running, print the exact SSH command that will be executed so the user can see it:

```
Connecting to <host>:
  ssh <args>
```

## Step 3 — Run it

Execute the command via the Bash tool with a generous timeout (600000ms), since this is an interactive SSH session.

```bash
ssh <resolved args>
```

For `vpn-server`, always use:
```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@150.136.232.63
```

For local hosts, use the NixOS hostname directly — no IP or key flag needed:
```bash
ssh bosko@<hostname>
```

## Step 4 — Report the result

After the session ends (or if the connection is refused/timed out), report the exit status briefly. No need to summarise what happened during the session.

---

## Key facts

- All local hosts have `AllowUsers bosko` (natalie-laptop also allows `natty`).
- All hosts have password auth disabled — key auth only.
- vpn-server uses the Oracle Cloud default `ubuntu` user; `bosko` does not exist there.
- Key path for vpn-server: `~/.ssh/id_ed25519`.
- Local hosts use ~/.ssh/config entries with static IPs (hostname resolution unreliable):
  - `gaming` → 10.0.0.251
  - `laptop` → 10.0.0.227
  - `natalie-laptop` → 10.0.0.103
  - `pi-hole` → 10.0.0.20
