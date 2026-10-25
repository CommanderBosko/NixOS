---
name: remote-rebuild
description: Use this skill when the user wants to "remote rebuild", "deploy to vpn-server", "rebuild vpn-server", "rebuild vpn-server remotely", or "nixos-rebuild remote". Deploys the NixOS configuration to the remote vpn-server host.
model: haiku
version: 0.2.0
---

# Remote NixOS Rebuild

Deploy the NixOS configuration to the remote headless **vpn-server** host from the local machine. vpn-server is the only valid remote target: it is the single non-local flake host (`gaming`, `laptop`, `natalie-laptop` rebuild locally with `nh os boot`). The old `nixos-server` is not a flake host — reject it.

## Arguments

**`<host>` (optional)** — if the user names a host, it's resolved through the shared alias lookup (`hosts_canonical` in `.claude/lib/hosts.sh`, see Target below) and validated against `vpn-server` — the only valid remote-rebuild target. A desktop host, the old `nixos-server` (not a flake host), or an unknown name all stop the skill with an explanation rather than proceeding. With no host named, the target defaults to `vpn-server` directly, since it's the only valid target anyway.

## Target — from the single source of truth

The vpn-server SSH target, arch, and deploy mode live in `/home/bosko/NixOS/.claude/hosts.json` — resolve them **once** into variables, then reuse those variables for every command below. Don't hardcode the literal IP or the deploy mode a second time anywhere in this flow:

```bash
VPN_SSH="$(jq -r '.hosts["vpn-server"].ssh' /home/bosko/NixOS/.claude/hosts.json)"
VPN_REBUILD="$(jq -r '.hosts["vpn-server"].rebuild' /home/bosko/NixOS/.claude/hosts.json)"
echo "$VPN_SSH $VPN_REBUILD"
```

`$VPN_REBUILD` is the `nixos-rebuild` subcommand to deploy with (currently `boot`). Step 2 is written for `boot` + reboot; if it prints anything else (including `null`), stop and ask via **AskUserQuestion** rather than improvising — never `switch` (see Gotchas).

If the user names a host, resolve the name through the shared alias lookup rather than comparing strings: `hosts_canonical` in `.claude/lib/hosts.sh` maps `vpn-server`'s aliases (`server`, `vpn`, `oracle`) to `vpn-server`:

```bash
TARGET="$(source /home/bosko/NixOS/.claude/lib/hosts.sh && hosts_canonical "$NAME")"
```

If `$TARGET` is not `vpn-server` — a desktop, the old `nixos-server` (not a flake host), or an unknown name (empty output) — explain it is not a valid remote-rebuild target and stop.

> **Pre-flight — known outage:** if Step 1 times out, check the `project_vpn_server_oracle_disabled` memory (2026-08-18 Oracle outage) before debugging firewall/security-list causes.

## Step 1 — Verify SSH connectivity

Using the `$VPN_SSH` value resolved above:

```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPN_SSH" echo ok
```

If it fails: "Check the Oracle VM is running and its security-list/firewall allows your current IP."

## Step 2 — Deploy with `$VPN_REBUILD` (`boot`) + reboot (NOT `switch`)

**vpn-server must be deployed with `nixos-rebuild "$VPN_REBUILD"` (hosts.json's `rebuild`, i.e. `boot`) followed by a reboot, not `switch`** — see Gotchas for why `switch` tears down the SSH session mid-activation. vpn-server is aarch64 while the local machine is x86_64 with no emulation, so `--build-host` is required (the ARM host builds its own closure).

Show the command before running it (substituting the resolved `$VPN_SSH` and `$VPN_REBUILD` values):

```
nixos-rebuild "$VPN_REBUILD" \
  --target-host "$VPN_SSH" \
  --build-host "$VPN_SSH" \
  --sudo \
  --flake /home/bosko/NixOS#vpn-server
```

This deploys and then reboots the sole public-facing remote host — the reboot drops every currently-connected client's WireGuard handshake (see Gotchas). Confirm before proceeding via the **AskUserQuestion** tool, options **Deploy and reboot** / **Cancel** — don't infer a "yes" from context, mirroring the confirm gate `nixos-gc`/`rollback`/`pin-input` use before their own state-changing steps.

Run it (long — 5–15 min; stream output so the user sees progress):

```bash
nixos-rebuild "$VPN_REBUILD" --target-host "$VPN_SSH" --build-host "$VPN_SSH" --sudo --flake /home/bosko/NixOS#vpn-server
```

Then reboot the host to activate the staged generation cleanly:

```bash
ssh "$VPN_SSH" 'sudo systemctl reboot'
```

## Step 3 — Post-reboot: hand off client tunnel restarts

Rebooting vpn-server drops every client's WireGuard handshake (see Gotchas) — but only for clients that were **on and connected through the reboot**. A client that's powered off at the time gets a fresh `wg-quick-wg0` start on its own next boot and handshakes normally; it never had a stale session to clear, so it needs no restart. Only ask about restarting for hosts confirmed online during (or shortly after) the reboot — check `/vpn-status` first rather than assuming all three peers need it.

**Do not restart the tunnels via the Bash tool** — none of `gaming`/`laptop`/`natalie-laptop` have a NOPASSWD sudo rule (only `vpn-server` does), so a non-interactive `ssh ... sudo systemctl restart` will fail with "a terminal is required to read the password," the same reason `rollback` hands off its privileged step.

For whichever hosts actually need it, print the restart commands and ask the user to run each one in their own separate terminal. Don't use the `!` prefix for these: it gives sudo no TTY, so the password prompt fails with "a terminal is required to read the password." This applies to the local host too:

```bash
/home/bosko/NixOS/.claude/skills/remote-rebuild/scripts/restore-tunnels.sh
```

If `modules/vpn.nix` is commented out of `desktopModules` in `flake.nix` (true while vpn-server is Oracle-disabled), the script says "tunnel module currently pulled … nothing to restart" and exits 0 — there is no `wg-quick-wg0` unit to restart, so skip this step. Otherwise it is read-only — it iterates `.claude/hosts.json`'s `flakeHosts` (skipping `vpn-server` itself) and prints the exact command for each host, without running any of them. Wait for the user to confirm, then run `/vpn-status` to verify the handshakes returned.

## Step 4 — Report result

On success, confirm: which host was updated, the new generation number if visible, any services restarted.

On failure, show the full error output, then match it against the common-causes list in `references/gotchas.md` (Deploy failures) before retrying.

---

## Key constraints

- The flake is always at `/home/bosko/NixOS`; the only remote target is `vpn-server` (read its SSH target from `.claude/hosts.json`).
- vpn-server: log in as `bosko` (root login is disabled; bosko has passwordless sudo for non-interactive deploys).
- Never attempt to remote-rebuild a desktop host — those use `nh os boot` locally.
- `boot` + reboot is the deploy method for vpn-server, not `switch` (hosts.json's `.hosts["vpn-server"].rebuild`; see Gotchas).

---

## Gotchas

If the deploy fails, or you need to justify why `boot`+reboot beats `switch` here, read `references/gotchas.md` for the root-caused failure modes and the common deploy-failure causes before improvising a fix.
