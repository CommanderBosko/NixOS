# Remote Rebuild — Gotchas

Load this if the deploy fails, or you need to justify why `boot` + reboot beats `switch` here.

- **`switch` over SSH gets killed mid-activation on vpn-server.** `nixos-rebuild-ng` runs `switch-to-configuration` as a `systemd-run --pipe` unit tied to the SSH connection. vpn-server's activation restarts networking (`network-setup`, `resolvconf`, `wg-quick-wg0`), which drops the SSH session — the broken pipe tears the activation down half-applied, leaving the firewall/NAT inconsistent (symptom: `MASQUERADE` present but FORWARD/conntrack at zero; clients connect but get no routing). **Deploy vpn-server with `nixos-rebuild boot` + reboot** (boot sets the bootloader default with no runtime activation, so SSH never drops; the reboot does a clean boot-time activation), or activate via a detached `systemd-run --collect … switch-to-configuration switch` on the host. An `exit 255` from a `switch` deploy almost always means this, not a sudo-password problem.
- **Rebooting/restarting vpn-server drops every client's WireGuard handshake — but only clients that were up at the time.** The server loses session state, so each full-tunnel client that was already connected black-holes all off-LAN traffic (kill-switch) until it re-handshakes — symptom: 100% packet loss to anything off-LAN, DNS hangs. After a server reboot, restart the tunnel on each *affected* client (`sudo systemctl restart wg-quick-wg0`); don't assume keepalive recovers it promptly. A client that was powered off through the reboot needs nothing — its `wg-quick-wg0` starts fresh on its own next boot (confirmed 2026-08-01: `laptop`/`natalie-laptop` were off during a vpn-server reboot and simply showed `Offline / never` in `/vpn-status` afterward, not a stale handshake to clear).
- **`--elevate {none,sudo,run0}` is silently unrecognized once `--target-host` or `--build-host` is also passed** (confirmed 2026-08-01, this nixos-rebuild-ng build): both `--elevate=sudo` and `--elevate sudo` fail with `error: unrecognized arguments`, even though `--elevate` alone (no remote host flags) parses fine and `--help` documents it as current. `--sudo` (the non-deprecated alias for `--elevate=sudo`) and the deprecated `--use-remote-sudo` both work fine in the same remote-host invocation — use `--sudo`.

## Deploy failures — common causes

Match the Step 4 error output against these before retrying:

- SSH connectivity lost mid-build: retry after checking the connection.
- `nix copy` fails: store-path transfer interrupted; retry.
- Evaluation error: fix the Nix config and re-run.
- `unrecognized arguments: --elevate=sudo` (or `--elevate sudo`): this nixos-rebuild-ng version can't parse `--elevate` alongside `--target-host`/`--build-host` — use `--sudo` instead (see the `--elevate` gotcha above).
- `--sudo` rejected at the remote end: verify bosko is in the wheel group and `security.sudo.wheelNeedsPassword = false` on the host.
- `platform mismatch ... Required system: 'aarch64-linux'`: the `--build-host` flag is missing — it's included in Step 2's command.
