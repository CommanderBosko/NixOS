# NixOS Configuration

Bosko's single-flake NixOS configuration for four hosts. Shared system modules live under `modules/`; Home Manager configs live under `dotfiles/` (`common/` shared by both users, `bosko/` user-specific); host-specific files (hardware config, environment, networking) live under `hosts/<hostname>/`.

## Current Status

Active development; `system.stateVersion` `25.11`. Four hosts — `gaming`, `laptop`, `natalie-laptop` (desktops, all on niri, tracking `nixos-unstable`) and `vpn-server` (headless `aarch64-linux`, on `nixos-25.11`) — with CI deep-evaluating every host on each push.

**The WireGuard full-tunnel VPN is down and out of the flake** (since 2026-08-18: Oracle Cloud administratively disabled the vpn-server instance, no ETA); a Tailscale mesh is the interim stopgap — see the [VPN](#vpn) section.

The current picture — what is live vs. pending a rebuild, open issues, next steps — lives in [`project-state.md`](project-state.md); the per-session narrative is in [`session-summary.md`](session-summary.md) (older sessions in `session-summary-archive.md`). Recent Changes below covers only the last few sessions.

## Features

- Single flake managing four active hosts (`gaming`, `laptop`, `natalie-laptop`, `vpn-server`) with shared module composition; `server` host deferred pending physical hardware
- **CI on every push/PR** (`.github/workflows/check.yml`): `nix flake check` plus a deep evaluation of every `nixosConfigurations.<host>` system derivation via the shared `.claude/lib/deep-eval.sh` (also what the `/deep-eval-check` skill runs) — eval-only (no builds, no secrets needed; the aarch64 vpn-server evaluates on the free x86 runner); it keeps going past a failing host and prints a per-host verdict, catching cross-host eval breakage that a shallow flake check provably misses. A further step asserts `.claude/hosts.json`'s flake hosts equal `nixosConfigurations`, and a weekly `de-smoke` job deep-evaluates every desktop-environment module via `lib.deSmoke`
- Home Manager integrated as a NixOS module for both users (`bosko` and `natty`); both users receive the same `home.nix` config — includes Helix editor config and SSH configuration
- SSH config managed declaratively via `programs.ssh.settings` in `dotfiles/common/configs/ssh.nix`; all five SSH hosts (natalie-laptop, laptop, gaming, pi-hole, famdash) defined with explicit `Hostname` and `User` fields; `enableDefaultConfig = false` suppresses implicit-defaults warnings
- **Managed Claude Code policy** deployed via `modules/claude-code.nix`; generates `/etc/claude-code/managed-settings.json` at activation time via `environment.etc`; enforces deny rules for destructive commands, ask rules for sensitive operations, and a PreToolUse fork bomb guard (`jq` pinned to its Nix store path); part of `commonModules` so all hosts share the same policy; users cannot override managed rules in their personal `~/.claude/settings.json`; `home.activation.trimClaudeSettings` in `dotfiles/bosko/claude-hm/settings.nix` strips the now-redundant deny/ask/hooks keys from `~/.claude/settings.json` on every rebuild once the managed file exists (idempotent, bosko only)
- Local LLM stack on gaming: Ollama with CUDA acceleration (`pkgs.ollama-cuda`, RTX 3070) serving `mistral-nemo:12b` (128K context, ~7GB Q4, fits in 8GB VRAM); Hermes Agent service configured to use the local Ollama OpenAI-compatible API at `http://localhost:11434/v1`; `hermes` CLI on system PATH; bosko in the `hermes` group for CLI access
- Jellyfin media server on gaming (`hosts/gaming/jellyfin-server.nix`): native `services.jellyfin` on a dedicated `/mnt/media` SSD with NVENC hardware transcoding (RTX 3070); firewall scoped to LAN + WireGuard + Tailscale, no other internet-facing ports; shared `media` group with setgid library dirs; `jellyfin-media-player` client shipped to all desktop hosts via `desktopModules`
- Pinchflat YouTube archiver on gaming (`hosts/gaming/pinchflat.nix`): native `services.pinchflat` (yt-dlp-backed), downloads into `/mnt/media/YouTube` sharing Jellyfin's `media` group, firewall scoped to LAN + WireGuard, `SECRET_KEY_BASE` via a dedicated sops secret
- FinanceGuru personal finance app installed on gaming and natalie-laptop via the `github:CommanderBosko/FinanceGuru` flake input
- Declarative Flatpak management via `nix-flatpak`
- Swappable desktop environment modules under `modules/desktop-environments/` (`lib.deSmoke` in `flake.nix` lists what is currently available), including a from-scratch Omarchy-style Hyprland module; all three desktop hosts currently run Niri (natalie-laptop briefly dual-booted Plasma 6 alongside it 2026-07-11 through 2026-07-18, then dropped)
- Declarative default-application (MIME type) associations via `xdg.mimeApps` in `dotfiles/common/configs/mimeapps.nix`: Thunar (file manager), xarchiver (archives), zathura (PDFs), imv (images), Kate (code/text), VLC (video/audio) — every mimetype verified against each app's real `.desktop` file, not guessed. Deliberately avoids KDE apps (Dolphin/Ark/Okular/Gwenview, used briefly then dropped 2026-07-17): their "open with" resolution depends on `kded6`, which niri never runs, making them unreliable outside a full Plasma session
- GPU modules correctly scoped: `amd.nix` gaming-only (not imported yet — `lib.moduleSmoke.amd` evaluates it in CI); `nvidia.nix` per-host explicit import (gaming, laptop, natalie-laptop) — ready for gaming AMD card swap by removing one line; also carries `GBM_BACKEND`/`__GLX_VENDOR_LIBRARY_NAME`/`LIBVA_DRIVER_NAME` session variables for Smithay-based compositors (Niri) that don't inherit KWin's automatic nvidia vendor-lib selection
- Gaming module with Steam, GameMode, Gamescope, MangoHud, lutris, faugus-launcher, nix-ld, and Steam hardware support — all gaming-specific config colocated in `gaming.nix`
- `claude-code` (plus `mcp-nixos`, `tailscale-mcp`, `rtk`) declared as user-level packages for `bosko` in `modules/claude-code.nix` (`gemini-cli` removed 2026-08-24, no longer used)
- Custom Claude Code subagents: sources in `dotfiles/bosko/claude/agents/*.md`, auto-discovered from that directory and symlinked into `~/.claude/agents/` via Home Manager (`dotfiles/bosko/claude-hm/files.nix`, no per-agent wiring — a new one just needs a `git add`), the same pattern as skills. Read-only fan-out units behind the `research`, `skill-audit`, `session-closer`, `skill-suggestion`, and `skill-upgrade` skills (`source-reviewer`, `skill-reviewer`, `transcript-scanner`); a `skill-builder` that builds pre-approved skill specs in parallel; and `manager`, which decides a delegated task the way this user would instead of interviewing at each step (backed by `manager-profile.md`, mined from Claude Code session history) — it verifies via each target project's own method, lands work only via branch+PR (never self-merged), and keeps hard limits that always require confirmation: no data destruction/force-push, no touching secrets, no spending money, no direct privileged/live-system execution, no pushing straight to `main`, no mutating MCP calls. They were built from analysis of real historical `Agent`-tool usage rather than speculatively; the `agent-suggestion` skill re-runs that analysis on demand. `ls dotfiles/bosko/claude/agents/` for the current roster
- Claude Code skill library: project-local skills under `.claude/skills/` (the NixOS workflow — dry-run, per-host deep evaluation, flake update/bump/pin, fleet status and rollout, SSH and remote rebuilds, sops secrets, VPN peers, niri/DE configuration, package and flatpak additions, CI status, diagnostics) plus repo-managed global skills under `dotfiles/bosko/claude/skills/`, symlinked into `~/.claude/skills/`; `ls` those directories for the current roster. Host SSH targets / IPs / the WireGuard peer map are centralized in `.claude/hosts.json` (single source of truth, read by every host-touching skill); deterministic work is factored into per-skill `scripts/` plus shared `.claude/lib/` scripts, large templates live in per-skill `assets/`, and skills whose work is mechanical are pinned to a cheaper model (`model: haiku` in frontmatter). The library is audited for quality on a recurring basis via `/skill-audit`
- WireGuard full-tunnel VPN (hub-and-spoke via Oracle Cloud free ARM VM): shared `vpn.nix` client module, per-host VPN addresses, full-tunnel routing (`0.0.0.0/0`), DNS override, keepalive=25 for Oracle's idle UDP timeout — **currently commented out of `desktopModules` (2026-08-18)**, since Oracle administratively disabled the vpn-server instance with no ETA; ready to restore once it's back
- Tailscale mesh (`modules/tailscale.nix`, added 2026-08-18) as the interim stopgap while wg0 is down: mesh-only (no exit-node/subnet-routing), manual per-host auth, **live on all 5 devices** — gaming/laptop/natalie-laptop via the flake module, pi-hole/famdash via a manual non-flake install
- Security hardening module (`security.nix`) active in `commonModules`: AppArmor MAC enforcement (`reloadIfChanged = false` works around a nixpkgs packaging bug in `apparmor-parser-5.0.0` that otherwise fails every activation needing an AppArmor reload — enforcement itself is unaffected), auditd (rules-loader service disabled due to nixpkgs/auditctl blank-line bug), kernel image protection, full ASLR, PAM wheel enforcement, SDDM PAM workaround, dbus-broker active on all hosts (explicit plain assignment overrides `nix-flatpak`'s bundled older nixpkgs)
- `~/.local/bin` in bosko's `home.sessionPath` (via `bosko-claude.nix`) so the native claude-code binary at `~/.local/bin/claude` is in PATH after rebuild
- Shared network folder for `bosko`/`natty` (`hosts/gaming/samba-shared.nix`, `modules/shared-folder-client.nix`): gaming serves `/srv/shared` via Samba (guest access, `openFirewall = true`); laptop and natalie-laptop CIFS-mount the same path, auto-mounting at boot (`nofail`, so a client boot never blocks on gaming being offline); both users' `~/Shared` symlinks to it on every host

## Getting Started

### Prerequisites

- NixOS installed on the target machine
- Flakes and `nix-command` enabled
- The `nh` helper tool (installed via the shell module)

### Installation

```bash
git clone https://github.com/CommanderBosko/NixOS /home/bosko/NixOS
cd /home/bosko/NixOS
```

### Rebuilding

```bash
# Stage a rebuild for next boot (also available as the `rebuild-boot` shell alias;
# `rebuild-switch` runs `nh os switch` instead, for changes that don't need a reboot)
nh os boot /home/bosko/NixOS

# Dry run — see what would change without applying
nh os boot /home/bosko/NixOS --dry

# Update all flake inputs
nix flake update

# Garbage collect old generations
sudo nix-collect-garbage -d
```

### Configuration

Each host has three files under `hosts/<hostname>/`:

- `hardware-configuration.nix` — generated by `nixos-generate-config`, hardware-specific
- `environment.nix` — packages, Flatpaks, display manager defaults
- `networking.nix` — hostname, DNS, firewall, SSH

Host-specific changes go in those files. Shared changes go in `modules/`.

## Project Structure

```
flake.nix                    # Single flake: inputs, commonModules/desktopModules, lib.mkSystem, the four hosts, lib.deSmoke
modules/                     # Shared system-level NixOS modules — which hosts import what is defined in flake.nix
└── desktop-environments/    # Swappable DE modules (lib.deSmoke evaluates each one)
dotfiles/
├── common/configs/          # Home Manager configs shared by bosko and natty (home.nix is the root)
└── bosko/                   # bosko-only HM config: bosko-claude.nix + claude-hm/ (Claude wiring) + claude/ (repo-owned global Claude skills and agents)
hosts/<hostname>/            # hardware-configuration.nix, environment.nix, networking.nix + any host-only modules
                             #   (headless vpn-server: configuration.nix + disko.nix instead)
secrets/                     # sops-nix encrypted secrets (see Secrets); recipient map in .sops.yaml
.claude/                     # Project-local Claude Code setup: skills/, lib/ (shared scripts), hooks/, hosts.json
.github/workflows/           # CI: flake check + deep evaluation of every host
```

Module, skill, and agent rosters change often — read `flake.nix` or run `ls modules/ .claude/skills/ dotfiles/bosko/claude/skills/ dotfiles/bosko/claude/agents/` rather than trusting a copy here.

### Module Composition

`flake.nix` defines a `mkSystem` helper (exported as `lib.mkSystem`) and two shared module lists — **it is the source of truth for what each list contains and what each host adds; read it rather than trusting a copy here.** `mkSystem` takes `{ name, system ? "x86_64-linux", nixpkgs ? nixos-unstable, modules }`, sets `networking.hostName` from `name`, and injects the shared `specialArgs`, so each host entry holds only its unique module list:

- **`commonModules`** — what every host needs, including the headless vpn-server: bootloader, base system configuration (nix settings, users, shell, localisation, fonts), security hardening, and secrets (sops)
- **`desktopModules`** — `commonModules` plus what a desktop host needs: Home Manager, Flatpak, and the shared desktop apps and services

Each host then adds its own desktop environment, hardware modules, and host-only services (see its entry in `flake.nix` and `hosts/<host>/`). The vpn-server uses only `commonModules` plus disko (`aarch64-linux`, `nixpkgs-stable`; headless, no DE).

`flake.nix` also exposes `lib.deSmoke` — the laptop config with each available DE module swapped in. CI's weekly `de-smoke` job deep-evaluates every one so unused DE modules can't rot silently across nixpkgs bumps.

### Users

| User | Groups | User-level packages |
|------|--------|---------------------|
| `bosko` | wheel, networkmanager, audio, video, input, kvm, libvirtd, lp, render | `claude-code` |
| `natty` | wheel, networkmanager, audio, video, input, kvm, libvirtd, lp, render | *(none)* |

Both users share the same Home Manager config (`home.nix`). `homeMode` is `"0700"` for both. Both users are wheel/sudo and Nix trusted users. `natty` has no user-level packages and no SSH keys. `mumble` is a system package on gaming only.

## Security

Security hardening is applied via `modules/security.nix`, which is part of `commonModules` and applies to all hosts.

Enabled hardening:

- **AppArmor** MAC enforcement (`security.apparmor.enable = true`, `killUnconfinedConfinables = false`) — processes without profiles are allowed, not killed (appropriate for desktop workloads)
- **auditd** — Linux audit daemon + `audit=1` kernel parameter; `audit-rules-nixos.service` is disabled via `lib.mkForce false` because `auditctl` 4.1.2-unstable rejects the blank line nixpkgs hard-codes in the generated `audit.rules`
- **D-Bus AppArmor mediation**
- **dbus-broker active** — `services.dbus.implementation = "broker"` (plain assignment, not `mkDefault`) in `security.nix` ensures dbus-broker is used on all hosts. The plain assignment is required because `nix-flatpak` bundles its own older nixpkgs that still defaults to `"dbus"` via `mkDefault`; a plain assignment beats any `mkDefault` regardless of source. All five hosts verified running `dbus-broker-launch` as of 2026-05-21.
- **PAM wheel-group enforcement** for sudo
- **Kernel image protection** — kexec disabled
- **Full ASLR** (`kernel.randomize_va_space = 2`)
- **SDDM PAM workaround** — gated behind `lib.mkIf config.services.displayManager.sddm.enable`; overrides the non-absolute module path that AppArmor's PAM integration rejects

SSH is hardened on gaming and laptop: `PasswordAuthentication = false`, `AllowUsers = [ "bosko" ]`, public key installed.

SSH is fully locked down on vpn-server: `PasswordAuthentication = false`, `PermitRootLogin = "no"` (set 2026-06-03). Remote deploys use `bosko@<vpn-endpoint>` (the endpoint address is kept out of the published README; resolve it from `.claude/hosts.json`) with `security.sudo.wheelNeedsPassword = false`.

## Secrets

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) and committed to the repo **encrypted**, which is what makes this configuration safe to publish. Plaintext secrets never live in the repo or the Nix store.

| Secret | File | Encrypted to |
|--------|------|--------------|
| `bosko` / `natty` login password hashes | `secrets/common.yaml` | admin + all hosts |
| Tailscale OAuth client credentials for the tailscale-mcp Claude Code connector (`tailscale-mcp-env`; readable by `bosko` only) | `secrets/desktop.yaml` | admin + desktop hosts (not vpn-server) |
| Discord webhook URL for the `send-results` Claude Code skill (`discord-webhook-url`; readable by `bosko` only) | `secrets/desktop.yaml` | admin + desktop hosts (not vpn-server) |
| Each host's WireGuard private key (`wg-private-key`) | `secrets/hosts/<host>.yaml` | admin + that host only |
| Pinchflat's `SECRET_KEY_BASE` (`pinchflat-env`) | `secrets/hosts/gaming.yaml` | admin + gaming only |
| Jellyfin API key for Claude-driven Jellyfin automation (`jellyfin-api-key`; not wired into any NixOS module — decrypted on demand) | `secrets/hosts/gaming.yaml` | admin + gaming only |

**How it works.** Each host derives its age identity from its existing SSH ed25519 host key (`/etc/ssh/ssh_host_ed25519_key`) — no extra key material is distributed. At activation, `sops-install-secrets` decrypts each secret to `/run/secrets/` (password hashes go to `/run/secrets-for-users/` via `neededForUsers = true`, so they exist before user accounts are created). The recipient map lives in `.sops.yaml`.

Wiring: the shared `secrets/common.yaml` secrets are declared in the sops module (part of `commonModules`); host-specific ones are declared next to the service that uses them. `grep -rn 'sops.secrets' modules hosts` shows the live wiring, and the file comments in `.sops.yaml` mirror the table above. Consumers read the decrypted path, e.g. `hashedPasswordFile = config.sops.secrets."<user>-hashedPassword".path` for users and `privateKeyFile = config.sops.secrets."wg-private-key".path` for WireGuard.

**Admin key.** Editing secrets requires the personal admin age key at `~/.config/sops/age/keys.txt`, kept out of the repo. Back it up — it is the recovery path if a host's SSH host key is ever lost.

**Git history.** The `main` branch was rewritten with `git filter-repo` on 2026-06-15 to purge the old plaintext password hashes. Run the `secret-scan` skill before publishing or pushing new branches/tags — it scans across **all** refs (not just `main`), which is what caught (and led to deleting) five stray old branches still leaking the pre-sops hashes on 2026-07-02.

```bash
# Edit a secret (decrypts in $EDITOR, re-encrypts on save)
sops secrets/common.yaml

# Add a new host as a recipient:
#   1. derive its age key:   ssh-to-age < ssh_host_ed25519_key.pub
#   2. add it to .sops.yaml (keys: + the relevant creation_rules)
#   3. re-encrypt:           sops updatekeys secrets/<file>.yaml
```

**Intentionally left in plaintext** (not secrets): all SSH/WireGuard *public* keys — these are public by nature and cannot be used on their own to gain access.

**Kept out of this published README** (operationally sensitive, not committed to the public docs): the VPN server's public endpoint address, and the LAN/VPN subnets and per-host addresses. These are not cryptographic secrets, but the README — being world-readable — should not hand a reader a map of reachable machines. They still live where the config needs them (host modules, `.claude/hosts.json`); this section only governs the README.

## VPN

**Status (2026-08-18): wg0 is down and out of the flake.** Oracle Cloud administratively disabled the vpn-server instance (`409 IncorrectState` on every instance action) and separately cut the tenancy's Always-Free ARM quota — not fixable via the API or from this repo. A Support ticket is filed with Oracle; no ETA. `modules/vpn.nix`'s import is commented out of `desktopModules` in `flake.nix` (not deleted) so no desktop host files a failing `wg-quick-wg0` unit at boot with no working endpoint — restoring it once vpn-server is back is a matter of uncommenting that import plus the per-host fragments it depends on. See **Tailscale** below for the interim stopgap.

WireGuard hub-and-spoke full-tunnel VPN, originally fully deployed 2026-05-18:

- **Server**: Oracle Cloud free-tier ARM VM (`aarch64-linux`), VPN gateway address on the `/24` tunnel subnet, standard WireGuard port. The public endpoint address and the tunnel subnet are kept out of this README (see Secrets); they live in the host config and `.claude/hosts.json`.
- **gaming / laptop / natalie-laptop**: VPN client address, private key via sops — `wg-quick-wg0` inactive while wg0 is out of the flake

All client traffic was routed through the server (`allowedIPs = ["0.0.0.0/0"]`) while active. The tunnel is **IPv4-only** — `networking.enableIPv6 = false` in `vpn.nix` disables IPv6 on all clients so traffic to IPv6-only hosts falls back to IPv4 through the tunnel instead of black-holing in the v4-only `wg0` (this is what was breaking Jellyfin's TMDb artwork fetches). `allowedIPs` is deliberately **v4-only**: with IPv6 disabled there is no stack to leak, and an `"::/0"` entry would make `wg-quick` try to install an IPv6 default route that fails ("IPv6 is disabled on nexthop device") and tears the tunnel down — so IPv6-off and the v4-only `allowedIPs` must always change together. `dns = [1.1.1.1 8.8.8.8]` in `vpn.nix` updates `resolv.conf` on interface up to avoid LAN resolver timeouts under full-tunnel. `persistentKeepalive = 25` prevents Oracle from dropping idle UDP sessions.

Key files: `modules/vpn.nix` (shared client config, currently unimported), `hosts/vpn-server/wireguard.nix` (server config with all peers and iptables MASQUERADE).

### Tailscale (interim stopgap while wg0 is down)

Added 2026-08-18 as a mesh-only fallback once the WireGuard hub went down: `modules/tailscale.nix` (`services.tailscale.enable = true`), no exit-node or subnet-routing, manual `sudo tailscale up` auth per host (no sops `authKeyFile` — only a handful of ad-hoc hosts, not a scale where automated auth pays for itself). **Live on 9 devices** — gaming, laptop, and natalie-laptop via the flake module; pi-hole and famdash via a manual install (non-flake, console-managed); two Android phones and, as of 2026-08-19, a TCL Google TV and an Amazon Fire TV Stick (both added purely so their Jellyfin apps use a stable tailnet address instead of a drifting LAN one — device-side only, no flake involvement) — all confirmed via `tailscale status` and the admin website. **Does not reproduce wg0's full-tunnel egress-IP masking** — it only connects the fleet's own devices to each other, so anything that depended on the VPN's shared egress IP (e.g. Pinchflat's yt-dlp bot-detection bypass) is not covered by this stopgap.

Desktop DNS (`modules/desktop-networking.nix`) now resolves through pi-hole's Tailscale IP (`100.92.242.60`) rather than its LAN IP, so ad-blocking/filtering survives being off the home LAN too — required flipping pi-hole's own `dns.listeningMode` from `LOCAL` to `ALL` on the appliance itself, since `LOCAL` silently drops queries from Tailscale's point-to-point-addressed interface. `1.1.1.1` stays as a fallback. Only gaming has switched onto this change so far; laptop and natalie-laptop still need their own `nh os switch`.

Pi-hole is also configured as a **global nameserver in the Tailscale admin console** (`100.92.242.60`, "Override local DNS" on, "Restrict to domain" off, "Use with exit node" on), layered on top of the flake-managed override above rather than replacing it — this is what actually gets pi-hole's filtering to non-flake tailnet members (pi-hole/famdash themselves, and any phone/tablet that joins) that have no NixOS config to carry a DNS override at all. Verified live on gaming (`host doubleclick.net` → `0.0.0.0` through the system resolver, matching a direct query to pi-hole); laptop/natalie-laptop not yet re-checked.

Jellyfin's firewall (`hosts/gaming/jellyfin-server.nix`) also opens 8096/tcp on `tailscale0` — `services.tailscale.enable` doesn't auto-open any ports on its own, so this needed adding explicitly once Tailscale became the only away-from-home path to Jellyfin with wg0 down. Jellyfin's own dashboard "LAN Networks" setting was also updated (`10.0.0.0/24,100.64.0.0/10`) so Tailscale clients get local-quality treatment rather than being throttled as remote.

## Recent Changes

_The last few sessions only — older history lives in `session-summary.md` / `session-summary-archive.md` and the commit history._

**2026-09-21 (session 114, latest)** — A repo-wide reorganization: config moved next to the modules that own it (dev toolchain, Claude packages, flatpak, SDDM, and bootloader/fonts/tailscale into `desktopModules`), the shared DMS stack and niri Home Manager config extracted, vpn-server split into focused files, and `bosko-claude.nix` now auto-wires Claude skills and agents from the directory listing (a new skill needs only `git add`). CI's deep-eval loop became one shared script that reports every failing host, a new `lib.moduleSmoke` evaluates modules no host imports, and the README and CLAUDE.md module lists were cut down to point at `flake.nix`. Verified by a 4-host deep-eval, all DE smoke checks and a before/after diff of evaluated contents. The Claude tooling secrets (`tailscale-mcp-env`, `discord-webhook-url`) moved to a new desktop-only `secrets/desktop.yaml` that vpn-server can't decrypt, and both credentials were rotated; along the way a secret-exposure incident (the `add-secret` skill wrongly claimed `!` commands aren't logged) was contained and the skill fixed to capture values in a separate terminal. Weekly `improve-system` PR #25 was reviewed and merged. Gaming is rebuilt; laptop and natalie-laptop still need a rebuild.

**2026-09-20 (session 113)** — Routine maintenance, no NixOS config changes beyond the lock. `/flake-update-verify` bumped `disko`, `dms`, `financeguru`, `home-manager`, `nixpkgs`, and `sops-nix` (`f978b9c`); `nix flake check` and a per-host deep-eval passed on all four hosts, and the bump was committed lock-only (gaming picked it up, together with the 2026-09-07 bump, on its 2026-09-20 reboot). On the pi-hole host (outside this repo), the `pihole-updatelists` config was found missing HaGeZi TIF and still listing an RPiList malware feed that had fallen out of the live list set; both are now in sync and gravity was rebuilt (29 lists). The `xwayland-satellite` 0.8.1 pin was re-checked twice against upstream issue #156 — still open, no newer release than 0.8.2 — so it stays. Close-out also corrected three stale `project-state.md` items that still described that pin as untested.

**2026-09-17 (session 112)** — Researched the Jellyfin plugin ecosystem via `/research` (no tool cleanly does declarative settings + declarative plugin installs; parked, saved to memory). Installed and verified live the YouTube-metadata plugin (reads Pinchflat's existing `info.json` sidecars, local reader only) and Intro Skipper (needed a manifest-URL fix — the documented URL 308-redirects to a dead page) on gaming's Jellyfin, driven via its REST API with a new dedicated `claude-automation` key. OpenSubtitles researched but not installed yet (needs a real account). Added the API key as a new sops secret (`jellyfin-api-key`) rather than a bare file, matching this repo's existing secret pattern since it's public. While doing that, found and fixed a real security gap in the existing `.claude/skills/add-secret` skill: its scripts had the *agent* running `sops set` with the plaintext as a literal argument and printing full decrypted output to the transcript — both violated `modules/sops.nix`'s own "never by an agent" rule; fixed in place (`fcae72c`). Also tried and reverted a Jellyfin library collection-type change (`tvshows`→`movies`) to get a flat thumbnail grid — Jellyfin's resolver still detects Pinchflat's dated-subfolder layout as TV-shaped regardless of declared type, so it achieved nothing; reverted cleanly.

## Roadmap

- Rebuild + reboot laptop and natalie-laptop (gaming is current as of 2026-09-21): activate managed Claude Code policy, FinanceGuru, package consolidation changes, the OnlyOffice font fix, and natalie-laptop's Plasma removal (niri-only now); remove hand-maintained `~/.ssh/config` on each host afterward
- Interface-scope Avahi mDNS: replace `openFirewall = true` in `printing.nix` with per-interface rules restricting UDP 5353 to the LAN interface
- AMD card swap on gaming: remove `nvidia.nix` from gaming's module list when card is physically replaced
- Harden vpn-server further (AppArmor profiles, fail2ban, rate-limiting on UDP 51820)
- Re-add `server` host via `/new-host` skill when physical hardware is available; pin to `nixpkgs-stable` following the vpn-server pattern

## License

Personal configuration — no formal license.
