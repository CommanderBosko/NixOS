# NixOS Project State

_Last updated: 2026-05-25_

## Current Project State

The configuration manages five NixOS hosts from a single flake. The WireGuard VPN is fully deployed and operational: Oracle Cloud ARM vpn-server is live, all three client hosts (gaming, laptop, natalie-laptop) have the shared `vpn.nix` module imported, real keys configured, and private keys placed. All three client interfaces are active.

**`~/.ssh/config` migrated into Home Manager declaratively (2026-05-25).** A new `dotfiles/common/configs/ssh.nix` module uses `programs.ssh.matchBlocks` to define all five SSH hosts: `natalie-laptop` (10.0.0.103, user bosko), `laptop` (10.0.0.227, user bosko), `gaming` (10.0.0.251, user bosko), `pi-hole` (10.0.0.20, user bosko), and `famdash` (10.0.0.21, user natalie). Imported from `home.nix` so both users receive the managed SSH config. Dry-run confirmed clean build.

**`vpn-on` / `vpn-off` shell aliases confirmed working (2026-05-22).** `vpn-on = "sudo systemctl start wg-quick-wg0"` and `vpn-off = "sudo systemctl stop wg-quick-wg0"` are now in `dotfiles/common/modules/shell.nix`. The systemd unit name uses a hyphen (`wg-quick-wg0`) which is how systemd renders the `wg-quick@wg0` template. Using `systemctl` avoids `wg-quick` binary PATH issues for non-root shell sessions.

**Non-login shell Home Manager session variables now sourced (2026-05-22).** `zsh.shellInit` in `shell.nix` now sources `~/.nix-profile/etc/profile.d/hm-session-vars.sh` when the file exists. This makes `sessionPath` (including `~/.local/bin`) and `sessionVariables` available to non-login zsh sessions (terminal emulators, scripted tool calls) — previously only login shells received them.

**`nixfmt-classic` replaced with `nixfmt` (2026-05-22).** The deprecated `nixfmt-classic` package was updated to `nixfmt` in both `shell.nix` (system package) and `helix.nix` (formatter reference). `flake.lock` updated accordingly.

**vpn-server: `audit=0` kernel param added (2026-05-22).** `boot.kernelParams = lib.mkAfter [ "audit=0" ]` in `hosts/vpn-server/configuration.nix` suppresses the Oracle Cloud ARM kernel's broken audit subsystem, which was flooding `kauditd` and dropping SSH connections mid-rebuild. The `mkAfter` placement ensures it wins over `security.nix`'s `audit=1` at boot without touching the shared module.

**nixpkgs channel split is complete (2026-05-21).** Desktop hosts (gaming, laptop, natalie-laptop) follow `nixos-unstable`. Server hosts (vpn-server, server) are pinned to `nixos-25.05` via a `nixpkgs-stable` input in `flake.nix`. vpn-server was deployed and confirmed running `25.05.20260102.ac62194 (Warbler)`. The `server` host placeholder was removed from `flake.nix` and `hosts/server/` (2026-05-21) — no hardware exists yet; the entry will be recreated via the `/new-host` skill when physical hardware arrives.

**Printing module added to desktopModules (2026-05-21, late session).** `dotfiles/common/modules/printing.nix` provides CUPS + Avahi mDNS printing with drivers (gutenprint, hplip, brlaser) for all desktop hosts. The module is now in `desktopModules` in `flake.nix`. Per-host printing entries previously duplicated in each host's `environment.nix` were removed. `kdePackages.print-manager` (the KDE print-job GUI) remains in `plasma.nix` — it is Plasma-specific and does not belong in the DE-agnostic printing module.

**dbus-broker transition is COMPLETE on all 5 hosts (2026-05-21).** `services.dbus.implementation = "broker"` is set as a plain (non-default) assignment in `security.nix`. This beats `nix-flatpak`'s bundled older nixpkgs whose `mkDefault "dbus"` was silently winning during module merge. All five hosts have been rebooted and verified running `dbus-broker-launch`.

**Claude Code skill library is at 22 skills (2026-05-21).** Lives under `.claude/skills/`. The `/nixos-rebuild` skill was removed after investigation confirmed `nh os boot` requires a real TTY for sudo and cannot be driven from a Claude Code subprocess. The apply step is always done by the user running `rebuild` in their terminal. Skills cover: dry-run, GC, VPN status, module scaffolding, commit, push, flake update, package/flatpak addition, desktop environment switching, new peer, SSH to any host, remote rebuild (headless targets), generation rollback, package search, new host scaffolding, flake input pinning, diff-generations, flake-check, journal, nix-repl, and fmt.

**`~/.local/bin` added to bosko's sessionPath (2026-05-21).** `home.sessionPath = [ "$HOME/.local/bin" ]` added to `dotfiles/bosko/bosko-claude.nix`. This ensures the native Claude Code binary installed at `~/.local/bin/claude` is discoverable in PATH, fixing the `/doctor` native binary check.

| Host | Status | DE |
|------|--------|----|
| `gaming` | **LIVE** — VPN client active (full-tunnel); private key placed; binfmt/aarch64 emulation for offline ARM builds; dbus-broker COMPLETE | plasma.nix |
| `laptop` | **LIVE** — VPN client active (full-tunnel); private key placed; `wg-quick-wg0` running; dbus-broker COMPLETE | niri.nix |
| `server` | **DEFERRED** — placeholder removed; no physical hardware yet; re-add via `/new-host` when hardware arrives | — |
| `natalie-laptop` | **LIVE** — VPN client active (full-tunnel); private key placed; DNS conflict fixed; dbus-broker COMPLETE | cosmic.nix |
| `vpn-server` | **LIVE** — Oracle Cloud ARM VM (`150.136.232.63`, `aarch64-linux`); wg0 active at `10.10.0.1/24`; three peers configured; pinned to nixos-25.05 (Warbler); dbus-broker COMPLETE | — |

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

**Security module is active.** `dotfiles/common/modules/security.nix` is in `commonModules` and applied on all hosts. Includes AppArmor MAC enforcement, auditd (running; rules-loader disabled), kernel image protection, ASLR, PAM wheel enforcement, SDDM PAM override workaround, and an explicit `services.dbus.implementation = "broker"` assignment (dbus-broker, COMPLETE on all hosts).

**Security audit completed 2026-05-06.** All Critical and High findings remediated. Most Medium and Low findings remediated. Three items explicitly deferred (see Known Issues).

## Current Goals

### Short-term (next 1-3 sessions)

- **Apply rebuilds on desktop hosts** — run `rebuild` + reboot on gaming, laptop, and natalie-laptop to activate the new `ssh.nix` managed SSH config and the `hm-session-vars.sh`/sessionPath fixes from 2026-05-22
- **AMD card swap on gaming** — when the physical card is swapped, remove `nvidia.nix` from gaming's module list in `flake.nix`; run `rebuild` in terminal and reboot
- **Re-enable lutris on gaming** — once nixpkgs-unstable ships a binary cache entry for `openldap-2.6.13-i686-linux`, uncomment `lutris` in `gaming.nix`
- **Re-add `server` host when hardware arrives** — use `/new-host` skill to scaffold; the pinning to `nixpkgs-25.05` via `nixpkgs-stable` input is the established pattern

### Long-term

- Harden vpn-server further with AppArmor profiles and fail2ban once stable channel is pinned
- Evaluate adding containerised services on the VPN server (its Oracle free-tier compute is otherwise idle)
- Explore adding fail2ban or rate-limiting on the WireGuard UDP port

## Recent Decisions

- **SSH config migrated into Home Manager via `programs.ssh.matchBlocks` (2026-05-25)** — All five SSH hosts are now declared in `dotfiles/common/configs/ssh.nix` with explicit `user` fields. Managed by HM means the SSH config is version-controlled, reproducible across hosts, and rebuilt automatically on each generation. Both users inherit the same block via `home.nix`. The previous hand-maintained `~/.ssh/config` file should be removed on each host after the next rebuild.
- **`vpn-on`/`vpn-off` aliases use `systemctl start/stop wg-quick-wg0` (2026-05-22)** — `wg-quick` is not in PATH for non-root zsh sessions; `systemctl` avoids the PATH dependency entirely. The systemd unit name is `wg-quick-wg0` (hyphen-joined), which is how systemd renders the `wg-quick@wg0` template instance.
- **`audit=0` appended on vpn-server via `lib.mkAfter` (2026-05-22)** — The Oracle Cloud ARM kernel's broken audit subsystem floods `kauditd` on boot, causing PAM D-Bus timeouts that drop SSH sessions during `nixos-rebuild switch`. Using `lib.mkAfter [ "audit=0" ]` in `hosts/vpn-server/configuration.nix` appends after `security.nix`'s `audit=1`; last value wins at boot. This avoids touching `security.nix` or disrupting other hosts.
- **`hm-session-vars.sh` sourced in `zsh.shellInit` (2026-05-22)** — Non-login shells (terminal emulators, scripted tool calls) do not automatically source the HM session vars file. Adding sourcing to `shellInit` (not `interactiveShellInit`) covers both interactive and non-interactive non-login sessions. The `if [ -f ... ]` guard is safe on hosts that have not yet been rebuilt.
- **`nixfmt-classic` replaced with `nixfmt` (2026-05-22)** — The `nixfmt-classic` package is deprecated upstream; `nixfmt` is the actively maintained successor. Updated in `shell.nix` (system package) and `helix.nix` (formatter reference).
- **Printing module extracted to `printing.nix` (2026-05-21, late session)** — Replaced duplicated per-host CUPS/Avahi config with a shared `dotfiles/common/modules/printing.nix` (CUPS, Avahi mDNS, gutenprint/hplip/brlaser drivers). Added to `desktopModules`. `kdePackages.print-manager` retained in `plasma.nix` — it is a KDE-specific print-job GUI and does not belong in a DE-agnostic module. Two-step commit: `print-manager` was first moved into `printing.nix` then corrected back to `plasma.nix`.
- **`~/.local/bin` added to bosko sessionPath (2026-05-21, evening)** — `home.sessionPath = [ "$HOME/.local/bin" ]` added to `dotfiles/bosko/bosko-claude.nix`. Diagnosed via `/doctor`: native claude-code binary installed at `~/.local/bin/claude` was not in PATH. Fix scoped to bosko's HM config (not shared with natty). Dry-run confirmed clean (+2.94 MiB closure, no package changes, no service restarts).
- **`server` placeholder removed from flake (2026-05-21, evening)** — `hosts/server/` directory and `flake.nix` entry deleted. The `server` host has no physical hardware; the placeholder was dead weight. Will be re-created via `/new-host` when hardware is available.
- **dbus-broker transition COMPLETE on all 5 hosts (2026-05-21)** — Root cause of resistance: `nix-flatpak` bundles its own older nixpkgs (`da5ad661`) whose `dbus.nix` defaults to `mkDefault "dbus"`, silently winning over nixpkgs-unstable's `mkDefault "broker"`. Fix: explicit (non-default) `services.dbus.implementation = "broker"` in `security.nix` beats all `mkDefault` values regardless of source. All five hosts verified via `systemctl status dbus`.
- **nixpkgs channel split (2026-05-21)** — Desktop hosts (gaming, laptop, natalie-laptop) stay on `nixos-unstable` for rolling updates. Server hosts (vpn-server, server) are pinned to `nixos-25.05` via a dedicated `nixpkgs-stable` input in `flake.nix`. Rationale: server stability and predictability outweigh the value of rolling updates for headless hosts; desktop hosts benefit from latest drivers and DE releases. vpn-server deployed and confirmed healthy on 25.05 with WireGuard peers intact.
- **CLAUDE.md corrections (2026-05-21)** — Three inaccuracies fixed: (1) `virtualisation` removed from `desktopModules` description — it is gaming-only; (2) `+ disko` added to vpn-server module composition; (3) directory layout tree corrected (`bosko/` indentation, `disko.nix` added to vpn-server listing). natty's wheel/trusted-user status corrected — she has both, same as bosko; the only differences are no user packages and no SSH keys.
- **Five new skills added (2026-05-21)** — `diff-generations` (nix store diff-closures between generations), `flake-check` (validate flake across all 5 hosts), `journal` (tail journald, local or remote), `nix-repl` (print repl command + host-specific starter expressions), `fmt` (alejandra with nixpkgs-fmt fallback). `nix-repl` prints rather than execs to avoid the TTY issue.
- **`/nixos-rebuild` skill removed (2026-05-20, night)** — `nh os boot` requires a controlling TTY for sudo; it cannot be run from a Claude Code subprocess. The correct workflow is: Claude edits config → user runs `rebuild` in their terminal. The `/nixos-dry-run` skill is unaffected (uses `--dry`, no sudo). `switch-de` next-steps updated to reference the `rebuild` alias directly.
- **Skill library extended to 18 skills (2026-05-20, second session)** — `ssh-host`, `remote-rebuild`, `rollback`, `search-pkg`, `new-host`, and `pin-input` added. The library now covers the full NixOS workflow surface: SSH, remote deployments, rollbacks, package discovery, host provisioning, and flake input management.
- **`pin-input` warns about follow-inputs (2026-05-20)** — When pinning `nixpkgs`, the skill explicitly warns that `home-manager` and `disko` follow nixpkgs by default and will also be pinned unless the user breaks those follows first.
- **`new-host` does not auto-edit `flake.nix` (2026-05-20)** — Shows the exact flake.nix entry to add (including correct `lib.mkSystem` call and module list) but requires the user to apply it. Same safe-by-default convention as `new-module`.
- **agenix deferred (2026-05-20)** — Explored agenix for managing WireGuard private keys declaratively; decided against it. VPN is fully working, no reinstalls expected, and adding agenix would require a full re-keying of all hosts. Plan saved at `/home/bosko/.claude/plans/agentix-wireguard-setup.md` for reference if a future reinstall happens.
- **Private keys confirmed out-of-repo (2026-05-20)** — WireGuard private keys live at `/etc/wireguard/private.key` on each host, referenced by path in the Nix config. They are never in the git repository. `.gitignore` already covers `*.key`.
- **Project-local Claude Code skill library started (2026-05-20, first session)** — Seven skills added initially: `nixos-dry-run`, `nixos-rebuild`, `nixos-gc`, `vpn-status`, `new-module`, `commit`, `push`. Skills travel with the repo and are version-controlled.
- **`new-module` skill does not auto-edit `flake.nix` (2026-05-20)** — Shows the exact import line to add but requires the user (or explicit follow-up) to apply it. Avoids silent modifications to the most critical file in the repo.
- **`commit` skill stages specific files, never `git add -A` (2026-05-20)** — Prevents accidentally committing private keys, `.env` files, or large build artifacts; falls back to `-A` only on explicit user request.
- **`nixos-gc` keeps 3 generations (2026-05-20)** — Matches the `cleanup` alias in `shell.nix`; retains rollback headroom without the destruction of `nix-collect-garbage -d`.
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

- **lutris disabled on gaming (upstream openldap regression)** — `openldap-2.6.13-i686-linux` has no binary cache entry in nixpkgs-unstable; `lutris` was commented out as a workaround. Re-enable once a cache entry appears. `faugus-launcher` covers the immediate need.
- **dbus-broker journal warnings are benign** — After the dbus-broker transition, three warning classes appear in journald: duplicate dbus service name entries (stricter parser), `Invalid group-name 'netdev'` in avahi-dbus.conf, `Invalid user-name 'systemd-timesync'` in timesync1.conf. All confirmed harmless; services function normally.
- **`server` host has no hardware** — Removed placeholder from flake; will be re-added via `/new-host` when physical hardware is available.

## Next Steps

1. **Apply rebuilds on desktop hosts**: run `rebuild` + reboot on gaming, laptop, and natalie-laptop to activate the new `ssh.nix` managed SSH config, the `hm-session-vars.sh` sourcing fix, and the `~/.local/bin` sessionPath fix. After each rebuild, remove the old hand-maintained `~/.ssh/config` on that host.
2. **AMD card swap on gaming**: when the physical card arrives, remove `nvidia.nix` from gaming's module list in `flake.nix`; run `rebuild` in terminal and reboot; verify `amd.nix` is sufficient on its own.
3. **Re-enable lutris when possible**: monitor nixpkgs-unstable for `openldap-2.6.13-i686-linux` binary cache entry; remove the comment-out from `gaming.nix`.
4. **Re-add `server` host when hardware arrives**: use `/new-host` skill to scaffold; pin to `nixpkgs-stable` (`nixos-25.05`) using the established pattern from vpn-server.
