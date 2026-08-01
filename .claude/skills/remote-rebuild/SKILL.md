---
name: remote-rebuild
description: Use this skill when the user wants to "remote rebuild", "deploy to vpn-server", "rebuild vpn-server", "rebuild vpn-server remotely", or "nixos-rebuild remote". Deploys the NixOS configuration to the remote vpn-server host.
model: haiku
version: 0.2.0
---

# Remote NixOS Rebuild

Deploy the NixOS configuration to the remote headless **vpn-server** host from the local machine. vpn-server is the only valid remote target: it is the single non-local flake host (`gaming`, `laptop`, `natalie-laptop` rebuild locally with `nh os boot`). The old `nixos-server` is not a flake host — reject it.

## Arguments

None — the target is fixed. This skill always deploys to `vpn-server`; there is no user-supplied argument to parse (mirrors `nixos-gc`'s "no arguments" style).

## Target — from the single source of truth

The vpn-server SSH target and arch live in `/home/bosko/NixOS/.claude/hosts.json` — resolve it **once** into a variable, then reuse that variable for every command below. Don't hardcode the literal IP a second time anywhere in this flow:

```bash
VPN_SSH="$(jq -r '.hosts["vpn-server"].ssh' /home/bosko/NixOS/.claude/hosts.json)"
echo "$VPN_SSH"
# bosko@150.136.232.63
```

If the user names any host other than `vpn-server` (a desktop, or the old `server`), explain it is not a valid remote-rebuild target and stop.

## Step 1 — Verify SSH connectivity

Using the `$VPN_SSH` value resolved above:

```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPN_SSH" echo ok
```

If it fails: "Check that the Oracle VM is running. If WireGuard is down on this machine, reach it via its public IP directly."

## Step 2 — Deploy with `boot` + reboot (NOT `switch`)

**vpn-server must be deployed with `nixos-rebuild boot` followed by a reboot, not `switch`** — see Gotchas for why `switch` tears down the SSH session mid-activation. vpn-server is aarch64 while the local machine is x86_64 with no emulation, so `--build-host` is required (the ARM host builds its own closure).

Show the command before running it (substituting the resolved `$VPN_SSH` value):

```
nixos-rebuild boot \
  --target-host "$VPN_SSH" \
  --build-host "$VPN_SSH" \
  --sudo \
  --flake /home/bosko/NixOS#vpn-server
```

Run it (long — 5–15 min; stream output so the user sees progress):

```bash
nixos-rebuild boot --target-host "$VPN_SSH" --build-host "$VPN_SSH" --sudo --flake /home/bosko/NixOS#vpn-server
```

Then reboot the host to activate the staged generation cleanly:

```bash
ssh "$VPN_SSH" 'sudo systemctl reboot'
```

## Step 3 — Post-reboot: hand off client tunnel restarts

Rebooting vpn-server drops every client's WireGuard handshake (see Gotchas) — but only for clients that were **on and connected through the reboot**. A client that's powered off at the time gets a fresh `wg-quick-wg0` start on its own next boot and handshakes normally; it never had a stale session to clear, so it needs no restart. Only ask about restarting for hosts confirmed online during (or shortly after) the reboot — check `/vpn-status` first rather than assuming all three peers need it.

**Do not restart the tunnels via the Bash tool** — none of `gaming`/`laptop`/`natalie-laptop` have a NOPASSWD sudo rule (only `vpn-server` does), so a non-interactive `ssh ... sudo systemctl restart` will fail with "a terminal is required to read the password," the same reason `rollback` hands off its privileged step.

For whichever hosts actually need it, print the restart commands and ask the user to run each themselves (suggest the `!` prefix for the local host):

```bash
/home/bosko/NixOS/.claude/skills/remote-rebuild/scripts/restore-tunnels.sh
```

This is read-only — it iterates `.claude/hosts.json`'s `flakeHosts` (skipping `vpn-server` itself) and prints the exact command for each host, without running any of them. Wait for the user to confirm, then run `/vpn-status` to verify the handshakes returned.

## Step 4 — Report result

On success, confirm: which host was updated, the new generation number if visible, any services restarted.

On failure, show the full error output. Common causes:
- SSH connectivity lost mid-build: retry after checking the connection.
- `nix copy` fails: store-path transfer interrupted; retry.
- Evaluation error: fix the Nix config and re-run.
- `unrecognized arguments: --elevate=sudo` (or `--elevate sudo`): this nixos-rebuild-ng version can't parse `--elevate` alongside `--target-host`/`--build-host` — use `--sudo` instead (see Gotchas).
- `--sudo` rejected at the remote end: verify bosko is in the wheel group and `security.sudo.wheelNeedsPassword = false` on the host.
- `platform mismatch ... Required system: 'aarch64-linux'`: the `--build-host` flag is missing — it's included in the command above.

---

## Key constraints

- The flake is always at `/home/bosko/NixOS`; the only remote target is `vpn-server` (read its SSH target from `.claude/hosts.json`).
- vpn-server: log in as `bosko` (root login is disabled; bosko has passwordless sudo for non-interactive deploys).
- Never attempt to remote-rebuild a desktop host — those use `nh os boot` locally.
- `boot` + reboot is the deploy method for vpn-server, not `switch` (see Gotchas).

---

## Gotchas

- **`switch` over SSH gets killed mid-activation on vpn-server.** `nixos-rebuild-ng` runs `switch-to-configuration` as a `systemd-run --pipe` unit tied to the SSH connection. vpn-server's activation restarts networking (`network-setup`, `resolvconf`, `wg-quick-wg0`), which drops the SSH session — the broken pipe tears the activation down half-applied, leaving the firewall/NAT inconsistent (symptom: `MASQUERADE` present but FORWARD/conntrack at zero; clients connect but get no routing). **Deploy vpn-server with `nixos-rebuild boot` + reboot** (boot sets the bootloader default with no runtime activation, so SSH never drops; the reboot does a clean boot-time activation), or activate via a detached `systemd-run --collect … switch-to-configuration switch` on the host. An `exit 255` from a `switch` deploy almost always means this, not a sudo-password problem.
- **Rebooting/restarting vpn-server drops every client's WireGuard handshake — but only clients that were up at the time.** The server loses session state, so each full-tunnel client that was already connected black-holes all off-LAN traffic (kill-switch) until it re-handshakes — symptom: 100% packet loss to anything off-LAN, DNS hangs. After a server reboot, restart the tunnel on each *affected* client (`sudo systemctl restart wg-quick-wg0`); don't assume keepalive recovers it promptly. A client that was powered off through the reboot needs nothing — its `wg-quick-wg0` starts fresh on its own next boot (confirmed 2026-08-01: `laptop`/`natalie-laptop` were off during a vpn-server reboot and simply showed `Offline / never` in `/vpn-status` afterward, not a stale handshake to clear).
- **`--elevate {none,sudo,run0}` is silently unrecognized once `--target-host` or `--build-host` is also passed** (confirmed 2026-08-01, this nixos-rebuild-ng build): both `--elevate=sudo` and `--elevate sudo` fail with `error: unrecognized arguments`, even though `--elevate` alone (no remote host flags) parses fine and `--help` documents it as current. `--sudo` (the non-deprecated alias for `--elevate=sudo`) and the deprecated `--use-remote-sudo` both work fine in the same remote-host invocation — use `--sudo`.
