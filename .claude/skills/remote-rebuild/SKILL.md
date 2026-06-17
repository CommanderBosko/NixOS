---
name: remote-rebuild
description: Use this skill when the user wants to "remote rebuild", "deploy to vpn-server", "deploy to server", "rebuild vpn-server", "rebuild server remotely", or "nixos-rebuild switch remote". Deploys a NixOS configuration to a remote host via nixos-rebuild switch --target-host.
version: 0.1.0
---

# Remote NixOS Rebuild

Deploy a NixOS configuration to a remote headless host (`vpn-server` or `server`) from the local machine using `nixos-rebuild switch --target-host`. Desktop hosts (gaming, laptop, natalie-laptop) are NOT valid targets — they rebuild locally with `nh os boot`.

## Valid remote targets

| Flake hostname | SSH target               | Architecture  | Notes                          |
|----------------|--------------------------|---------------|--------------------------------|
| `vpn-server`   | `bosko@150.136.232.63`   | aarch64-linux | Oracle Cloud ARM, WireGuard hub |
| `server`       | `bosko@nixos-server`     | x86_64-linux  | Local headless server          |

## Step 1 — Determine target

If the user supplied a hostname as an argument (e.g. `/remote-rebuild vpn-server`), use it. Otherwise ask:

```
Which remote host do you want to rebuild?
  1. vpn-server  (bosko@150.136.232.63 — Oracle Cloud ARM)
  2. server      (bosko@nixos-server — local headless server)
```

Accept the number, the short name (`vpn-server`, `server`), or an unambiguous prefix. If the user names a desktop host, explain it is not a valid remote-rebuild target and stop.

## Step 2 — Verify SSH connectivity

Before running the rebuild, do a quick connectivity check:

For `vpn-server`:
```bash
ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=10 -o BatchMode=yes bosko@150.136.232.63 echo ok
```

For `server`:
```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes bosko@nixos-server echo ok
```

If the check fails, report the error and stop with a suggestion:
- vpn-server: "Check that the Oracle VM is running and that WireGuard is connected (the VPN carries traffic for the 10.10.0.0/24 subnet; if WireGuard is down on this machine you may need to reach it via its public IP directly)."
- server: "Check that the server is powered on and reachable on the local network."

## Step 3 — Show the exact command

Display the full command before running it so the user can confirm:

For `vpn-server`:
```
nixos-rebuild switch \
  --target-host bosko@150.136.232.63 \
  --build-host bosko@150.136.232.63 \
  --elevate=sudo \
  --flake /home/bosko/NixOS#vpn-server
```

`--build-host` is required for vpn-server: it is aarch64 and the local machine is x86_64 with no emulation, so the ARM host must build its own closure. (`server` is x86_64, so it builds locally and omits `--build-host`.)

For `server`:
```
nixos-rebuild switch \
  --target-host bosko@nixos-server \
  --elevate=sudo \
  --flake /home/bosko/NixOS#server
```

Note to the user: "This will take several minutes. For `server` it builds locally then copies the closure; for `vpn-server` (`--build-host`) it evaluates locally but builds on the ARM host, which fetches cached paths over its own connection."

## Step 4 — Run the rebuild

Run the appropriate command. This is long-running (can take 5–15 minutes depending on what changed). Stream output so the user can see progress.

For `vpn-server`:
```bash
nixos-rebuild switch --target-host bosko@150.136.232.63 --build-host bosko@150.136.232.63 --elevate=sudo --flake /home/bosko/NixOS#vpn-server
```

For `server`:
```bash
nixos-rebuild switch --target-host bosko@nixos-server --elevate=sudo --flake /home/bosko/NixOS#server
```

## Step 5 — Report result

On success, confirm:
- Which host was updated
- The new generation number if visible in the output
- Any services that were restarted

On failure:
- Show the full error output
- Common causes:
  - SSH connectivity lost mid-build: retry after checking the connection
  - `nix copy` fails: store path transfer interrupted; retry
  - Evaluation error: fix the Nix config and re-run
  - `--elevate=sudo` rejected: verify bosko is in the wheel group and that `security.sudo.wheelNeedsPassword = false` is set on the remote host
  - `platform mismatch ... Required system: 'aarch64-linux'`: the local x86_64 machine can't build vpn-server's aarch64 derivations. Use `--build-host bosko@150.136.232.63` so the ARM host builds its own closure natively (already included in the vpn-server command above)

---

## Key constraints

- The flake is always at `/home/bosko/NixOS`.
- vpn-server SSH key: `~/.ssh/id_ed25519`, login as `bosko` (root login is disabled; bosko has passwordless sudo for non-interactive deploys).
- server SSH login: `bosko@nixos-server` (hostname set in `hosts/server/networking.nix`).
- Never attempt to remote-rebuild a desktop host — those use `nh os boot` locally.
- Do not reboot the remote host after the rebuild unless the user explicitly requests it. `nixos-rebuild switch` activates the new generation immediately without a reboot.
