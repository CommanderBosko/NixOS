# NixOS Project State

_Last updated: 2026-05-18_

## Current Project State

The configuration manages five NixOS hosts from a single flake. The WireGuard VPN is fully deployed and operational: Oracle Cloud ARM vpn-server is live, all three client hosts (gaming, laptop, natalie-laptop) have the shared `vpn.nix` module imported and real keys configured. Gaming's private key is placed and `wg-quick-wg0` is active. Laptop and natalie-laptop still need their private keys placed manually before the interface will start.

| Host | Status | DE |
|------|--------|----|
| `gaming` | **LIVE** — VPN client active (full-tunnel); private key placed; binfmt/aarch64 emulation for offline ARM builds | plasma.nix |
| `laptop` | **LIVE** — VPN config deployed; private key placement pending (manual step before `wg-quick-wg0` starts) | niri.nix |
| `server` | Active — headless | — |
| `natalie-laptop` | **LIVE** — WireGuard peer (10.10.0.4) with real keys; `vpn.nix` imported; DNS conflict with LAN nameserver fixed; private key placement pending | cosmic.nix |
| `vpn-server` | **LIVE** — Oracle Cloud ARM VM (`150.136.232.63`, `aarch64-linux`); wg0 active at `10.10.0.1/24`; three peers configured (gaming, laptop, natalie-laptop) | — |

**Starship config inlined (2026-05-17).** The external `starship.toml` dotfile has been eliminated. The full Gruvbox-themed Starship prompt configuration now lives as a native `programs.starship.settings` attrset in `shell.nix`. `dotfiles/common/configs/starship.toml` and the `xdg.configFile` symlink in `home.nix` were both removed.

**Helix auto-format disabled globally (2026-05-17).** All language blocks in `helix.nix` now have `auto-format = false` set uniformly.

**Stale NordVPN configs deleted (2026-05-17).** The `dotfiles/vpn/` directory (two `.conf` files and an `auto-auth.txt`) was removed. These were dead code from before the WireGuard approach.

**Nerd Font v3 symbol spacing fixed (2026-05-17).** Nine starship module symbols in `shell.nix` had a trailing space added to render correctly in Nerd Font v3.

**tmux added to gaming (2026-05-17).** `tmux` is now a system package on the gaming host.

**Repository restructured (2026-05-15).** Host-specific files moved from `dotfiles/<hostname>/` into a new top-level `hosts/<hostname>/` directory. Bosko-specific Home Manager configs (`bosko-claude.nix` and `claude/agents/`) moved from `dotfiles/common/configs/` into `dotfiles/bosko/`. All `flake.nix` paths updated; dry-run passed cleanly after both moves.

**`rebuild` alias now uses `nh os boot`.** As of 2026-05-12, the `rebuild` shell alias stages changes for the next reboot rather than attempting a live switch.

**AMD card swap preparation in progress.** `nvidia.nix` was removed from `desktopModules` on 2026-05-14 and is now listed explicitly per-host. When the physical NVIDIA card is replaced with AMD on gaming, removing `nvidia.nix` from gaming's module list in `flake.nix` is the only change needed.

**Home Manager reorganised.** `home-manager.nix` was refactored into a single nested `home-manager { }` block; `stateVersion` was moved here from `home.nix`; natty's block now correctly imports `home.nix` (previously missing).

**`claude-code` and `gemini-cli` moved to user-level packages.** Both tools are now declared in `users.users.bosko.packages` in `users.nix` rather than repeated per-host in `environment.nix`.

**Security module is active.** `dotfiles/common/modules/security.nix` is in `commonModules` and applied on all hosts. Includes AppArmor MAC enforcement, auditd (running; rules-loader disabled), kernel image protection, ASLR, PAM wheel enforcement, SDDM PAM override workaround, and a pin for classic dbus.

**Security audit completed 2026-05-06.** All Critical and High findings remediated. Most Medium and Low findings remediated. Three items explicitly deferred (see Known Issues).

## Current Goals

### Short-term (next 1-3 sessions)

- **Place laptop WireGuard private key** — manually write the private key to `/etc/wireguard/private.key` on the laptop (key is in the VPN setup memory), then run `rebuild` to activate `wg-quick-wg0`
- **Place natalie-laptop WireGuard private key** — same manual step; key available from the VPN key-generation session
- **AMD card swap on gaming** — when the physical card is swapped, remove `nvidia.nix` from gaming's module list in `flake.nix`; run `rebuild` and reboot
- **Re-enable lutris on gaming** — once nixpkgs-unstable ships a binary cache entry for `openldap-2.6.13-i686-linux`, uncomment `lutris` in `gaming.nix`
- **Validate dbus-broker** — classic dbus is pinned in `security.nix`; once AppArmor profile compatibility is confirmed, dbus-broker can be re-enabled
- **M-9: Pin server to `nixos-25.05` stable** — add a second nixpkgs input in `flake.nix`

### Long-term

- Harden vpn-server further with AppArmor profiles and fail2ban once stable channel is pinned
- Evaluate adding containerised services on the VPN server (its Oracle free-tier compute is otherwise idle)
- Explore adding fail2ban or rate-limiting on the WireGuard UDP port

## Recent Decisions

- **Full-tunnel VPN routing chosen (2026-05-18)** — `allowedIPs = ["0.0.0.0/0" "::/0"]` routes all client traffic through the Oracle server, hiding the client's real IP. Split-tunnel (VPN subnet only) was briefly in place but replaced in the same session.
- **DNS promoted to shared `vpn.nix` (2026-05-18)** — `dns = [1.1.1.1 8.8.8.8]` was first added as a natalie-laptop-specific workaround (LAN resolver `10.0.0.20` is unreachable via full-tunnel), then recognized as universally correct and moved to the shared module. All three client hosts now inherit it automatically on `vpn.nix` import.
- **ARM server builds natively (2026-05-18)** — `server-rebuild` now SSHs to the Oracle ARM server and builds there; `binfmt` aarch64 emulation is available on gaming as an offline fallback. Cross-compiling `aarch64` on `x86_64` without explicit cross-compilation config fails with a platform mismatch.
- **VPN subnet `10.10.0.0/24` (2026-05-18)** — Chosen to avoid overlap with Oracle's internal LAN (`10.0.0.x`). Server: `10.10.0.1`; gaming: `10.10.0.2`; laptop: `10.10.0.3`; natalie-laptop: `10.10.0.4`.
- **`trustedInterfaces + checkReversePath = "loose"` on vpn-server (2026-05-18)** — Required for the firewall to forward peer packets and accept asymmetric NAT return traffic arriving on `enp0s6`.
- **Starship config inlined into `shell.nix` (2026-05-17)** — Eliminates the external TOML dotfile and its `xdg.configFile` symlink. The configuration is a first-class Nix attrset evaluated at build time; the full Gruvbox-themed prompt with all module settings was preserved. Single source of truth, no runtime file management.
- **Helix auto-format disabled globally (2026-05-17)** — Applied uniformly with `auto-format = false` across all configured languages. Prevents unexpected reformatting during editing sessions; format manually when needed.
- **NordVPN `dotfiles/vpn/` deleted (2026-05-17)** — Dead code from before the WireGuard approach. No path back to NordVPN in the current design.
- **Host directories moved to `hosts/` (2026-05-15)** — All five host-specific directories (`gaming`, `laptop`, `natalie-laptop`, `server`, `vpn-server`) relocated from `dotfiles/<hostname>/` to `hosts/<hostname>/`. Clarifies the repo layout: `dotfiles/` now holds only shared and user-specific HM configs; `hosts/` holds machine-specific NixOS config.
- **Bosko-specific HM configs moved to `dotfiles/bosko/` (2026-05-15)** — `bosko-claude.nix` and `claude/agents/` relocated from `dotfiles/common/configs/` to `dotfiles/bosko/`. Makes the user-scope of these files explicit; `dotfiles/common/configs/` now contains only configs shared by both users.
- **`nvidia.nix` scoped per-host (2026-05-14)** — Removed from `desktopModules`; each desktop host (gaming, laptop, natalie-laptop) now imports it explicitly. Preparation for the gaming AMD card swap: dropping NVIDIA from gaming will require only a one-line flake change.
- **`rebuild` alias switched to `nh os boot` (2026-05-12)** — Avoids live-switch activation failures. Changes are staged; rebooting applies them.
- **`claude-code` and `gemini-cli` moved to `users.nix` user packages (2026-05-14)** — User-scoped tools belong in `users.users.bosko.packages`, not duplicated across per-host `environment.nix` files.
- **Cleanup retention reduced to 3 builds (2026-05-14)** — 3 generations is sufficient rollback headroom; saves disk space.
- **natty now gets `home.nix` applied (2026-05-14)** — The `home-manager.nix` reorganisation added the missing `home.nix` import to natty's HM block. Previously natty had a HM block with no imports.
- **`lutris` commented out in gaming.nix (2026-05-12)** — `lutris` transitively depends on `openldap-2.6.13` for `i686-linux`; that derivation has no binary cache entry and attempting to build it from source blocks `nh os switch` for hours. Workaround: `# lutris` comment in `gaming.nix`; `faugus-launcher` (already in the list) covers the use-case. Restore once a binary cache entry exists.
- **`audit-rules-nixos.service` disabled (2026-05-11)** — `auditctl` 4.1.2-unstable rejects blank lines in `audit.rules`; nixpkgs hard-codes one before `-e 1`. Disabling the service via `systemd.services.audit-rules-nixos.enable = lib.mkForce false` is cleaner than patching nixpkgs. `auditd` continues running (required for AppArmor). If custom audit rules are needed in future, load them via a separate unit.
- **`natty` restored as non-wheel user (2026-05-11)** — Removed in the 2026-05-06 audit for being in the wheel group. Now back with no elevated privileges (no wheel, no trusted-user) for the Natalie laptop host.
- **`vpn.nix` deleted (2026-05-11)** — File had been commented out in `flake.nix` since April; deleted to reduce dead code. Will be rewritten from scratch when VPN deployment is imminent.
- **`amd.nix` scoped to gaming host only (2026-05-11)** — The laptop has no AMD GPU; `amd.nix` was incorrectly in `desktopModules`. Now imported only in the gaming host's module list.
- **dbus pinned to classic implementation (2026-05-10)** — nixpkgs-unstable rev `4bd9165` silently changed `services.dbus.implementation` default to `"broker"`. Fix: `services.dbus.implementation = lib.mkDefault "dbus";` in `security.nix`. Broker should not be re-enabled until validated against this AppArmor configuration.
- **Full security audit remediation (2026-05-06)** — All Critical, High, and most Medium/Low findings addressed in a single session. Rationale: the gaming host is blocked by an unrelated upstream regression anyway; best to get the config into a hardened state before the next activation.
- **L-6 declined** — User chose not to change `edit = "sudo hx"` alias to `sudoedit`; alias retained as-is.
- **chrony replaces ntpd** — Applied to all three hosts; handles intermittent connectivity better.
- **WireGuard keys deferred** — Placeholder keys are not a real risk until VPN is deployed; generating them without a live peer adds no security value.
- **Stable nixpkgs pin deferred (M-9)** — Requires adding a second nixpkgs input to flake.nix; scoped to a future session.
- **Claude agents backed up via HM** — `bosko-claude.nix` symlinks agent definitions from the repo into `~/.claude/agents/` on rebuild. Confirmed on laptop (switch succeeded 2026-05-10); gaming pending its switch.
- **nix-ld consolidated into gaming.nix** — All gaming-specific config is colocated in one module.

## Known Issues / Tech Debt

- **Laptop and natalie-laptop WireGuard private keys not yet placed** — The `wg-quick-wg0` service is configured but will not start until the private key file exists at `/etc/wireguard/private.key`. Keys are documented in the nixos-agent VPN memory; placement is a manual step on each machine.
- **lutris disabled on gaming (upstream openldap regression)** — `openldap-2.6.13-i686-linux` has no binary cache entry in nixpkgs-unstable; `lutris` was commented out as a workaround. Re-enable once a cache entry appears. `faugus-launcher` covers the immediate need.
- **dbus-broker not yet validated** — Classic dbus is pinned in `security.nix`. dbus-broker cannot be adopted until its AppArmor profile is verified compatible with this config.
- **M-9 deferred** — vpn-server and all other hosts still run `nixos-unstable`. Should be pinned to `nixos-25.05` for stability on the server; requires a new flake input.

## Next Steps

1. **Place laptop WireGuard private key**: on the laptop, run the key placement commands from the nixos-agent VPN memory, then run `rebuild` to activate `wg-quick-wg0.service`
2. **Place natalie-laptop WireGuard private key**: same process on natalie-laptop
3. **AMD card swap on gaming**: when the physical card arrives, remove `nvidia.nix` from gaming's module list in `flake.nix`; run `rebuild` and reboot; verify `amd.nix` is sufficient
4. **Re-enable lutris when possible**: monitor nixpkgs-unstable for `openldap-2.6.13-i686-linux` binary cache entry; remove the comment-out from `gaming.nix`
5. **Validate dbus-broker**: test dbus-broker AppArmor compatibility on the current config; if clean, remove the `lib.mkDefault "dbus"` pin from `security.nix`
6. **Pin server to `nixos-25.05` (M-9)**: add stable nixpkgs input in `flake.nix`; configure vpn-server to follow it
