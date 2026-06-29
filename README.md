# NixOS Configuration

Bosko's single-flake NixOS configuration for five hosts. Shared modules live under `dotfiles/common/`; bosko-specific Home Manager configs live under `dotfiles/bosko/`; host-specific files (hardware config, environment, networking) live under `hosts/<hostname>/`.

## Current Status

Active development, state version `25.11`. Four active hosts (gaming, laptop, natalie-laptop, vpn-server); `server` host placeholder removed pending physical hardware. Desktop hosts (gaming, laptop, natalie-laptop) track `nixos-unstable`; vpn-server is pinned to `nixos-25.11` (Xantusia) for stability (bumped from EOL 25.05 on 2026-06-17). WireGuard full-tunnel VPN is fully operational. A Jellyfin media server runs on gaming (NVENC transcoding, LAN+VPN-only) and is confirmed working across all devices. dbus-broker active on all hosts. SSH config managed declaratively via Home Manager. A managed Claude Code policy is deployed system-wide via `dotfiles/common/modules/claude-code.nix` (active on gaming; laptop and natalie-laptop pending rebuild+reboot). `bosko-claude.nix` now includes a declarative HM activation script that automatically trims redundant deny/ask/hooks keys from `~/.claude/settings.json` on every rebuild once the managed policy file is present. natalie-laptop switched to Plasma 6 (pending rebuild). FinanceGuru installed on gaming and natalie-laptop. lutris re-enabled on gaming. Security hardening completed 2026-06-03: root SSH disabled on vpn-server, SDDM auto-login disabled on gaming (active/confirmed).

## Features

- Single flake managing four active hosts (`gaming`, `laptop`, `natalie-laptop`, `vpn-server`) with shared module composition; `server` host deferred pending physical hardware
- Home Manager integrated as a NixOS module for both users (`bosko` and `natty`); both users receive the same `home.nix` config — includes Helix editor config and SSH configuration
- SSH config managed declaratively via `programs.ssh.settings` in `dotfiles/common/configs/ssh.nix`; all five SSH hosts (natalie-laptop, laptop, gaming, pi-hole, famdash) defined with explicit `Hostname` and `User` fields; `enableDefaultConfig = false` suppresses implicit-defaults warnings
- **Managed Claude Code policy** deployed via `dotfiles/common/modules/claude-code.nix`; generates `/etc/claude-code/managed-settings.json` at activation time via `environment.etc`; enforces deny rules for destructive commands, ask rules for sensitive operations, and a PreToolUse fork bomb guard (`jq` pinned to its Nix store path); part of `commonModules` so all hosts share the same policy; users cannot override managed rules in their personal `~/.claude/settings.json`
- Local LLM stack on gaming: Ollama with CUDA acceleration (`pkgs.ollama-cuda`, RTX 3070) serving `mistral-nemo:12b` (128K context, ~7GB Q4, fits in 8GB VRAM); Hermes Agent service configured to use the local Ollama OpenAI-compatible API at `http://localhost:11434/v1`; `hermes` CLI on system PATH; bosko in the `hermes` group for CLI access
- Jellyfin media server on gaming (`hosts/gaming/jellyfin-server.nix`): native `services.jellyfin` on a dedicated `/mnt/media` SSD with NVENC hardware transcoding (RTX 3070); firewall scoped to LAN + WireGuard only; shared `media` group with setgid library dirs; `jellyfin-media-player` client shipped to all desktop hosts via `desktopModules`
- FinanceGuru personal finance app installed on gaming and natalie-laptop via the `github:CommanderBosko/FinanceGuru` flake input
- Declarative Flatpak management via `nix-flatpak`
- Swappable desktop environment modules (11 options under `desktop-environments/`); gaming and natalie-laptop on Plasma 6, laptop on Niri
- GPU modules correctly scoped: `amd.nix` gaming-only; `nvidia.nix` per-host explicit import (gaming, laptop, natalie-laptop) — ready for gaming AMD card swap by removing one line
- Gaming module with Steam, GameMode, Gamescope, MangoHud, lutris, faugus-launcher, nix-ld, and Steam hardware support — all gaming-specific config colocated in `gaming.nix`
- `claude-code` and `gemini-cli` declared as user-level packages in `users.nix` for both `bosko` and `natty`
- Claude agent definitions (`repo-creator-agent.md`, `session-closer.md`) backed up declaratively via Home Manager and symlinked into `~/.claude/agents/`; `home.activation.trimClaudeSettings` in `bosko-claude.nix` automatically strips redundant deny/ask/hooks keys from `~/.claude/settings.json` on every rebuild once the managed policy file is present (idempotent; no-op until the managed file exists; scoped to bosko only)
- Project-local Claude Code skill library under `.claude/skills/`: 31 skills covering the full NixOS workflow — dry-run, GC, VPN status, module scaffolding, new host (sops-aware), new peer, commit, push, flake update, single-input bump, package/flatpak addition, desktop environment switching, SSH to any host, remote headless deployment, generation rollback, package search, flake input pinning, generation diff, flake validation, journal tailing, nix repl, .nix formatting, sops secret management, a fleet health sweep, leaked-secret scanning, post-rebuild service verification, and memory writing. Host SSH targets / IPs / the WireGuard peer map are centralized in `.claude/hosts.json` (single source of truth, read by every host-touching skill); deterministic work is factored into per-skill `scripts/` plus a shared `.claude/lib/flake-lock-diff.sh`, and large templates live in per-skill `assets/`
- WireGuard full-tunnel VPN deployed (hub-and-spoke via Oracle Cloud free ARM VM): shared `vpn.nix` client module, per-host VPN addresses, full-tunnel routing (`0.0.0.0/0`), DNS override, keepalive=25 for Oracle's idle UDP timeout; all three client hosts configured
- Security hardening module (`security.nix`) active in `commonModules`: AppArmor MAC enforcement, auditd (rules-loader service disabled due to nixpkgs/auditctl blank-line bug), kernel image protection, full ASLR, PAM wheel enforcement, SDDM PAM workaround, dbus-broker active on all hosts (explicit plain assignment overrides `nix-flatpak`'s bundled older nixpkgs)
- `~/.local/bin` in bosko's `home.sessionPath` (via `bosko-claude.nix`) so the native claude-code binary at `~/.local/bin/claude` is in PATH after rebuild

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
# Stage a rebuild for next boot (also available as the `rebuild` shell alias)
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

Host-specific changes go in those files. Shared changes go in `dotfiles/common/modules/`.

## Project Structure

```
dotfiles/
└── common/
    ├── modules/                        # System-level NixOS modules
    │   ├── desktop-environments/       # 11 swappable DE modules (niri, plasma, cosmic, …)
    │   ├── security.nix                # AppArmor, auditd, kernel hardening, PAM enforcement
    │   ├── amd.nix                     # AMD GPU drivers (gaming host only)
    │   ├── nvidia.nix                  # NVIDIA GPU drivers (all desktop hosts)
    │   ├── audio.nix                   # Pipewire
    │   ├── gaming.nix                  # Steam, GameMode, Gamescope, MangoHud, nix-ld, steam-hardware (gaming only)
    │   ├── emulation.nix               # RetroArch
    │   ├── virtualisation.nix          # Podman (Avahi restricted to virbr0)
    │   ├── sddm.nix                    # Display manager
    │   ├── bootloader.nix              # GRUB + zen kernel (desktop hosts)
    │   ├── firmware.nix                # fwupd
    │   ├── fonts.nix, localisation.nix, nix.nix, shell.nix, users.nix
    │   └── home-manager.nix            # HM module entrypoint for bosko and natty
    └── configs/                        # Home Manager configs shared by both users
        ├── home.nix                    # HM root — imported by both bosko and natty
        ├── helix.nix
        ├── ssh.nix                     # Declarative SSH config (programs.ssh.settings)
        └── dotfiles (katerc, kitty.conf)

dotfiles/bosko/                         # bosko-specific HM configs (not shared with natty)
├── bosko-claude.nix                    # Symlinks Claude agent definitions into ~/.claude/agents/
└── claude/agents/                      # Claude agent definitions (repo-creator-agent.md, session-closer.md)

hosts/
├── gaming/                             # hardware-configuration.nix, environment.nix, networking.nix
├── laptop/                             # same three files
├── natalie-laptop/                     # same three files (real hardware data from nixos-generate-config)
└── vpn-server/                         # configuration.nix, disko.nix, hardware-configuration.nix (live on Oracle Cloud ARM)

.claude/skills/                         # Project-local Claude Code skills (25 total)
├── nixos-dry-run/                      # Preview config changes without applying (nh os boot --dry)
├── nixos-gc/                           # Garbage-collect Nix store, keep last 3 generations
├── vpn-status/                         # SSH to VPN server and display WireGuard peer table
├── new-module/                         # Interactive NixOS module scaffolder (3 templates)
├── commit/                             # Conventional commit workflow with user confirmation
├── push/                               # Push to origin main with ahead/behind check
├── update/                             # nix flake update with readable lock diff
├── add-package/                        # Add package to correct host or user scope
├── add-flatpak/                        # Declaratively add a Flatpak to a host's environment.nix
├── switch-de/                          # Swap desktop environment import in flake.nix
├── new-peer/                           # Add a new WireGuard peer to vpn-server
├── ssh-host/                           # SSH to any known host by short name
├── remote-rebuild/                     # nixos-rebuild switch --target-host for headless hosts
├── rollback/                           # Show generations, confirm, then switch --rollback
├── search-pkg/                         # nix search nixpkgs wrapper with add-package nudge
├── new-host/                           # Scaffold a new host (desktop/server/remote-arm types)
├── pin-input/                          # Pin a flake input to a rev/tag (lock-only or permanent)
├── diff-generations/                   # nix store diff-closures between current and previous generation
├── flake-check/                        # Validate flake across all 5 hosts before rebuild or commit
├── journal/                            # Tail journald for a named service, local or remote
├── nix-repl/                           # Print nix repl command + host-specific starter expressions
├── fmt/                                # Format changed .nix files (alejandra, nixpkgs-fmt fallback)
├── add-secret/                         # Add / edit / rotate a sops-nix secret
├── fleet-status/                       # Read-only health sweep across all four hosts
└── secret-scan/                        # Scan working tree + git history for leaked secrets
```

### Module Composition

`flake.nix` defines a `lib.mkSystem` helper and two module lists:

- **`commonModules`** — base for all hosts: firmware, fonts, localisation, nix settings, shell, users, security
- **`desktopModules`** — `commonModules` + bootloader, home-manager, nix-flatpak, audio, emulation, SDDM

Each desktop host then adds its own machine-specific modules. Notable per-host additions:
- **gaming**: `amd.nix`, `gaming.nix`, `nvidia.nix`, `virtualisation.nix`, `plasma.nix` (virtualisation is gaming-only, not in desktopModules)
- **laptop**: `nvidia.nix`, `niri.nix`
- **natalie-laptop**: `nvidia.nix`, `plasma.nix` (switched from cosmic.nix 2026-06-04)
- **vpn-server**: `commonModules` only (`aarch64-linux`, systemd-boot, disko)

### Users

| User | Groups | User-level packages |
|------|--------|---------------------|
| `bosko` | wheel, networkmanager, audio, video, input, kvm, libvirtd, lp, render | `claude-code`, `gemini-cli` |
| `natty` | wheel, networkmanager, audio, video, input, kvm, libvirtd, lp, render | `gemini-cli` |

Both users share the same Home Manager config (`home.nix`). `homeMode` is `"0700"` for both. Both users are wheel/sudo and Nix trusted users. `natty` has no user-level packages and no SSH keys. `mumble` is a system package on gaming only.

## Security

Security hardening is applied via `dotfiles/common/modules/security.nix`, which is part of `commonModules` and applies to all hosts.

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
| Each host's WireGuard private key | `secrets/hosts/<host>.yaml` | admin + that host only |

**How it works.** Each host derives its age identity from its existing SSH ed25519 host key (`/etc/ssh/ssh_host_ed25519_key`) — no extra key material is distributed. At activation, `sops-install-secrets` decrypts each secret to `/run/secrets/` (password hashes go to `/run/secrets-for-users/` via `neededForUsers = true`, so they exist before user accounts are created). The recipient map lives in `.sops.yaml`.

Wiring:

- `dotfiles/common/modules/sops.nix` — imports the sops-nix module and declares the shared password secrets (part of `commonModules`)
- `users.nix` — `hashedPasswordFile = config.sops.secrets."<user>-hashedPassword".path`
- `vpn.nix` and `hosts/vpn-server/configuration.nix` — `privateKeyFile = config.sops.secrets."wg-private-key".path`

**Admin key.** Editing secrets requires the personal admin age key at `~/.config/sops/age/keys.txt`, kept out of the repo. Back it up — it is the recovery path if a host's SSH host key is ever lost.

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

WireGuard hub-and-spoke full-tunnel VPN, fully deployed as of 2026-05-18.

- **Server**: Oracle Cloud free-tier ARM VM (`aarch64-linux`), VPN gateway address on the `/24` tunnel subnet, standard WireGuard port. The public endpoint address and the tunnel subnet are kept out of this README (see Secrets); they live in the host config and `.claude/hosts.json`.
- **gaming**: VPN client address — private key via sops, `wg-quick-wg0` active
- **laptop**: VPN client address — private key via sops, `wg-quick-wg0` active
- **natalie-laptop**: VPN client address — private key via sops, `wg-quick-wg0` active

All client traffic is routed through the server (`allowedIPs = ["0.0.0.0/0"]`). The tunnel is **IPv4-only** — `networking.enableIPv6 = false` in `vpn.nix` disables IPv6 on all clients so traffic to IPv6-only hosts falls back to IPv4 through the tunnel instead of black-holing in the v4-only `wg0` (this is what was breaking Jellyfin's TMDb artwork fetches). `allowedIPs` is deliberately **v4-only**: with IPv6 disabled there is no stack to leak, and an `"::/0"` entry would make `wg-quick` try to install an IPv6 default route that fails ("IPv6 is disabled on nexthop device") and tears the tunnel down — so IPv6-off and the v4-only `allowedIPs` must always change together. `dns = [1.1.1.1 8.8.8.8]` in `vpn.nix` updates `resolv.conf` on interface up to avoid LAN resolver timeouts under full-tunnel. `persistentKeepalive = 25` prevents Oracle from dropping idle UDP sessions.

Key files: `dotfiles/common/modules/vpn.nix` (shared client config), `hosts/vpn-server/configuration.nix` (server config with all peers and iptables MASQUERADE).

## Recent Changes

**2026-06-28 (latest, session 21)** — Gave the two session-reactive maintenance skills awareness of past conversation history. `skill-upgrade` and `skill-suggestion` previously analyzed only the live session; both now also `grep` the project's stored transcripts (under `~/.claude/projects/`) so that a skill misfire recurring across sessions is treated as the highest-value fix, and a workflow repeated across many sessions is recognized as the strongest candidate for a new skill. Both carry a grep-not-read guard since transcripts can be multi-megabyte. The other skills `/improve-system` chains were left as-is (`claude-rules` and `skill-audit` don't need history; `fewer-permission-prompts` already scans it). Claude-tooling only — no NixOS system config touched.

**2026-06-28 (session 20)** — Two changes, both to the Claude tooling layer (no NixOS system config touched). (1) Added a global **`/improve-system`** orchestrator skill that chains the five Claude-ecosystem maintenance skills — `skill-upgrade`, `skill-suggestion`, `claude-rules`, `skill-audit`, and `fewer-permission-prompts` — into a single pass: it auto-applies low-risk additive changes (skill gotchas, CLAUDE.md rules, permission-allow entries) and gates structural ones (new skills, audit refactors) behind confirmation, invoking each sub-skill rather than reimplementing it. (2) Scrubbed operationally-sensitive network detail (the VPN server's public endpoint address and the VPN/LAN subnets + per-host addresses) out of this public README and added a "no sensitive information" guardrail to the `session-closer` skill's README step so future updates keep it clean — a README-only change; the values still live in the host config where the tunnel needs them.

**2026-06-26** — Routine flake update with one caveat: the 2026-06-26 `nixos-unstable` rev shipped a broken `linux-zen-7.0.12` (installs `vmlinuz` but declares its target as `bzImage`, failing the bootloader sanity check on all zen-kernel hosts — vpn-server, on standard `linuxPackages`, is unaffected). The dry-run caught it, so **`nixpkgs` was pinned back lock-only** to the prior good rev `567a49d1` while the other five inputs (`dms`, `financeguru`, `home-manager`, `nixpkgs-stable`, `sops-nix`) were kept at latest. The next `nix flake update` will lift the pin automatically once upstream ships `bzImage` again. Lock bump only — not yet applied.

**2026-06-23** — Full audit and overhaul of the Claude skill library (7 commits, no NixOS system config changed). Added a **4-bucket single-responsibility gate** to `new-skill` and a new global **`/skill-audit`** meta-skill that sweeps every skill against that gate plus five structural lenses (deterministic→`scripts/`, templates→`assets/`, re-entered-config→shared JSON, pick-ones→AskUserQuestion, inputs→`## Arguments`). New skills: **`bump-input`** (bump one flake input to latest), **`save-memory`**, and **`team-member-synthesize`** (split out of `team-member-ingest`). Fixed real drift bugs the audit surfaced — `/vpn-status` was broken (used the denied `ubuntu@` user; corrected fleet-wide to `bosko@`, verified live), the commit skills stamped the wrong model trailer, `new-host`'s DE list named five nonexistent modules, and `pin-input`'s input roster was stale (DE list and roster now enumerate live). Centralized host SSH targets / IPs / the WireGuard peer map into **`.claude/hosts.json`** (single source of truth) and rewired the host-touching skills + `fleet-status`/`vpn-status` scripts to read it; removed the phantom `nixos-server` host. Extracted deterministic work into per-skill `scripts/` (and a shared `.claude/lib/flake-lock-diff.sh`), moved `new-host`'s nine inlined Nix templates into `assets/` (493→180 lines), and added AskUserQuestion/`## Arguments` polish across ~11 skills. **Pending:** the `dotfiles/`-based skill changes (`new-skill`, `git-commit`, `team-member-*`, `/skill-audit`) go live in `~/.claude` after the next rebuild + reboot; project-local skill changes are already live.

**2026-06-22** — Bumped the **FinanceGuru** flake input for an upstream update (lock-only). Added a `.gitignore` rule for **loop run-logs** (`.claude/loops/**/output-*.md` and `memory-*.md`) so each loop run's dual-file output stays local instead of cluttering `git status`. The loop *skills* themselves live in `.claude/skills/` and remain tracked (portable to any clone); loop *config* files like `.claude/loops/public-repo-guard/baseline-allowlist.md` stay tracked too — only the dated per-run logs are ignored.

**2026-06-21** — Generated the first three loops with `/create-loop` (confirming the meta-skill works end-to-end). Each is a project-local, self-orchestrating loop under `.claude/skills/`, runnable immediately: **`/fleet-rollout`** deploys the committed config across `gaming → laptop → natalie-laptop → vpn-server` one host at a time — dry-run gate → `switch` (activate live) → full health sweep (new generation, zero failed units, no reboot-pending, fresh WG handshake on vpn-server), advancing only on green; local host via `nh os switch`, the rest via `remote-rebuild`. **`/flake-update-verify`** runs `nix flake update` → `flake-check`, then **commits the `flake.lock` bump without applying it** (apply is `/fleet-rollout`'s job), and **restores the previous lock** if the update breaks eval. **`/public-repo-guard`** runs `secret-scan` + `audit-config`, triaging every finding against a seeded baseline allowlist (`.claude/loops/public-repo-guard/baseline-allowlist.md`) and passing only at zero genuine findings — a pre-push / periodic guard for this public repo. All three default to Loop Training Mode ON with a retry cap of 3 and dual-file run output under `.claude/loops/<name>/`.

**2026-06-20** — Added a global **`/create-loop`** meta-skill (`dotfiles/bosko/claude/skills/create-loop/SKILL.md`, wired into `bosko-claude.nix`). It interviews for a task's goal, ordered steps, and done-rule, then generates a **project-local, self-orchestrating loop skill** at `.claude/skills/<loop>/SKILL.md` that runs as a single command `/<loop-name>` — no rebuild needed (only `/create-loop` itself, being repo-owned, requires one to activate). Every generated loop bakes in: **Loop Training Mode** (a top-of-file toggle, ON by default — ON pauses at each step for approval, skips steps already passing their done-rule, re-runs only failures, respects a retry cap; OFF runs autonomously but keeps the done-rule checks and the cap), a **retry cap** (default 3/step), **dual-file output every run** (`.claude/loops/<loop>/output-<date>.md` for the artifact + `memory-<date>.md` for what worked/failed/remember-next, read back at the next run's start), and a **verification plan** where the done-rule is the bar. Generated loops are project-local and standalone by design (confirmed via `/interview`): no rebuild friction, and each loop is a complete, inspectable artifact rather than a thin `/loop` wrapper.

**2026-06-18** — Rewrote the `Parallelize with Sub-Agents` standing workflow rule (in both `CLAUDE.md` and the global `claude-rules` skill) so it actually triggers. The old wording was an aspirational value with no trigger condition and was silently losing to the harness's "don't spawn agents unless asked" default. The new version grants explicit standing authorization to spawn sub-agents, frames the parallelization check as a mandatory pre-task gate, and lists observable trigger conditions (2+ independent research areas / 2+ unreferenced files / planning "A→B→C where B doesn't need A"), while naming the coupled-edits exception (a module + its `flake.nix` import are correctly serial) so the rule no longer reads as self-contradictory. Docs-only; the skill text reaches `~/.claude` on the next rebuild.

**2026-06-17** — Bumped the `nixpkgs-stable` input from EOL **`nixos-25.05`** to current stable **`nixos-25.11`** (Xantusia) and redeployed vpn-server onto it. The deploy surfaced three latent issues, all fixed/captured: (1) clamped `wg0` MTU to **1380** in the shared `vpn.nix` — wg-quick's default 1420 exceeded the Oracle tunnel's ~1400-byte path MTU, silently truncating large `cache.nixos.org` downloads; (2) the `remote-rebuild` skill now uses `--build-host` (the x86_64 deployer can't build the aarch64 closure) and `--elevate=sudo` (replaces deprecated `--use-remote-sudo`); (3) vpn-server must be deployed via **`nixos-rebuild boot` + reboot**, not `switch` — `switch` over SSH ties activation to the SSH pipe, and the network restart drops the connection and corrupts the half-applied firewall/NAT (this, not a 25.11 regression, took the VPN down mid-session; recovered via a detached rollback). Both deploy gotchas are now documented in the `remote-rebuild` skill. The `mtu = 1380` clamp applies to the desktop clients on their next rebuild.

**2026-06-17 (session 12)** — Promoted the **mcp-nixos** server from project scope to **user scope** so Claude Code can query live NixOS package/option/version data in every project, not just this repo. The redundant project `.mcp.json` was removed (`claude mcp add … --scope user` registers it in `~/.claude.json` instead). To stay reproducible, a new `home.activation.claudeMcpServers` block in `dotfiles/bosko/bosko-claude.nix` idempotently reconciles the `.mcpServers.nixos` entry with `jq` on every rebuild — `~/.claude.json` is mutable state Claude rewrites constantly, so it's reconciled rather than symlinked, matching the existing `claudeAllowList`/`claudeNixdPlugin` activation pattern.

**2026-06-17 (later)** — Fixed `wg-quick-wg0.service` failing on rebuild. Disabling IPv6 the day before (below) left `"::/0"` in the WireGuard peer's `allowedIPs`; `wg-quick` installs a route per allowedIP, so `ip -6 route add ::/0 dev wg0` failed on the now-IPv6-disabled device and `wg-quick` tore the tunnel down — meaning the VPN had silently failed to come up on every boot since. Dropped `"::/0"`, leaving `allowedIPs = ["0.0.0.0/0"]` (still a full tunnel with no IPv6 to leak), and added a `NOTE:` so it isn't re-added while IPv6 is off. Applies to all three clients via the shared `vpn.nix`. Also added an **mcp-nixos** MCP server (`pkgs.mcp-nixos`) so Claude Code can query live NixOS package/option data (promoted to user scope the same day — see latest entry).

**2026-06-17** — Fixed Jellyfin artwork/metadata failing to load on gaming. The cause was a VPN routing issue, not Jellyfin: TMDb resolves to IPv6-only addresses, but the full-tunnel WireGuard client routes `::/0` into a v4-only `wg0`, so all IPv6 traffic black-holed and TMDb requests hung the 100s HTTP timeout. Added `networking.enableIPv6 = false` to the shared `dotfiles/common/modules/vpn.nix` to force IPv4 fallback through the tunnel — fixes the black-hole while keeping the full-tunnel guarantee (no IPv6 leak). Applies to all three VPN clients (gaming, laptop, natalie-laptop); gaming needs a rebuild + reboot to activate.

**2026-06-16 (later)** — Enabled sudo **password masking** fleet-wide: `security.sudo.extraConfig = "Defaults pwfeedback";` in `dotfiles/common/modules/security.nix` (part of `commonModules`) so the sudo prompt now prints a `*` per typed character. The historical pwfeedback CVE (CVE-2019-18634) is fixed in the shipped sudo, noted inline. Confirmed working on gaming.

**2026-06-16** — Stood up a **Jellyfin media server** on gaming (`hosts/gaming/jellyfin-server.nix`): native `services.jellyfin` backed by the spare 1TB Samsung SSD (ext4, mounted at `/mnt/media`, pinned by UUID), NVENC hardware transcoding via the RTX 3070, and a firewall scoped to LAN (`enp4s0`) + WireGuard (`wg0`) only — no internet-facing ports. A shared `media` group with setgid library dirs keeps manual drops readable by the scanner. `jellyfin-media-player` added to `desktopModules` so every desktop host ships the client. **Confirmed working on all devices.** Replaced the headless `qbittorrent-nox` service with the `qbittorrent` desktop GUI app (drops the listening Web UI; saves to `/mnt/media/downloads` so finished torrents stay scannable). Added a project-local `verify-service` skill — a read-only post-rebuild service health sweep — distilled from this session's by-hand verification.

**2026-06-15 (later)** — Added a fourth standing workflow rule, **Use Existing Skills First**, to the global `claude-rules` skill and to `CLAUDE.md`: prefer an existing skill over doing a task by hand (complements the existing "Skill Awareness" create-a-skill guidance). Also corrected the `famdash` SSH host login in `dotfiles/common/configs/ssh.nix` (`natalie` → `natty`).

**2026-06-15** — Adopted [sops-nix](https://github.com/Mic92/sops-nix) so the repo can be made public without leaking secrets (supersedes the 2026-05-20 decision to defer agenix). Login password hashes (`bosko`, `natty`) and all four per-host WireGuard private keys are now encrypted in `secrets/` and consumed via `hashedPasswordFile` / `privateKeyFile`; `users.nix` no longer contains plaintext hashes. Each host decrypts with an age key derived from its SSH ed25519 host key; the admin key stays at `~/.config/sops/age/keys.txt` (out of repo). WireGuard keys verified identity-preserving (derived pubkeys match the server's registered peers) and all four hosts rebuilt with live handshakes confirmed. Git history was rewritten with `git filter-repo` to purge the old plaintext password hashes from all commits. See the [Secrets](#secrets) section. _(The VPN endpoint address and tunnel subnet, originally noted here as public, are now kept out of this README — see Secrets.)_

**2026-06-09** — Three sessions of Claude Code policy work. (1) `dotfiles/common/modules/claude-code.nix` created to deploy `/etc/claude-code/managed-settings.json` system-wide; also: `gemini-cli` added to natty's user packages; `nodejs`, `pnpm`, `p7zip`, and `jq` consolidated from per-host `environment.nix` files into `shell.nix`. (2) Rebuilt and rebooted gaming to activate the managed policy; trimmed personal `~/.claude/settings.json` manually using the one-shot trim script, then deleted the script. (3) Replaced the deleted script with a declarative `home.activation.trimClaudeSettings` in `dotfiles/bosko/bosko-claude.nix`: on every rebuild, once the managed file exists, the activation script uses `jq` to strip redundant deny/ask/hooks keys while leaving personal prefs intact. Idempotent. laptop and natalie-laptop still need rebuild+reboot to activate the managed policy.

**2026-06-05/04** — natalie-laptop switched from Cosmic to Plasma 6. `krohnkite` (KWin tiling script) added to shared `plasma.nix` so both gaming and natalie-laptop get it automatically. FinanceGuru personal finance app added to gaming and natalie-laptop as a flake input (`github:CommanderBosko/FinanceGuru`). lutris re-enabled on gaming — the upstream `openldap-2.6.13-i686-linux` binary cache regression that blocked it since May 2026 is resolved in nixpkgs-unstable.

**2026-06-03** — Security audit and hardening pass. Multi-agent review across all six security domains identified three real findings. Two remediated: (1) `PermitRootLogin` changed from `"prohibit-password"` to `"no"` on vpn-server; `security.sudo.wheelNeedsPassword = false` added for non-interactive `nixos-rebuild --use-remote-sudo` deploys as bosko; (2) SDDM `autoLogin.enable = false` on gaming (now active and confirmed). Third finding — Avahi mDNS `openFirewall = true` in `printing.nix` — deferred: closing it would break printer discovery; interface-scoped firewall rules are the correct fix. Updated `remote-rebuild` skill to target `bosko@<vpn-endpoint>` (address resolved from `.claude/hosts.json`).

**2026-05-26** — Deployed a local LLM stack on gaming. New `hosts/gaming/hermes-agent.nix` enables Ollama with CUDA acceleration (`pkgs.ollama-cuda`) and Hermes Agent service, both pointing to `http://localhost:11434/v1`. Model settled on `mistral-nemo:12b` after iterating through four options: it is the only model satisfying Hermes Agent's 64K context minimum, fitting in 8GB VRAM (~7GB Q4), and providing good tool-calling support. `bosko` added to the `hermes` group so the interactive `hermes` CLI can traverse `/var/lib/hermes`. `hermes-agent` added as a flake input. Also corrected the SSH config module from the deprecated `programs.ssh.matchBlocks` API to `programs.ssh.settings`, capitalised option keys, added `enableDefaultConfig = false`, and added a global keepalive stanza.

**2026-05-25** — Migrated `~/.ssh/config` into Home Manager declaratively. New `dotfiles/common/configs/ssh.nix` defines all five SSH hosts (`natalie-laptop`, `laptop`, `gaming`, `pi-hole`, `famdash`) with explicit `Hostname` and `User` fields. Imported from `home.nix` so both users receive the managed config automatically on each rebuild. The hand-maintained `~/.ssh/config` on each host should be removed after the next rebuild.

**2026-05-22** — Added `vpn-on` / `vpn-off` shell aliases to `shell.nix`. Uses the systemd service (`wg-quick-wg0`) rather than `wg-quick` directly (the binary is not in PATH for non-root zsh sessions). Added `boot.kernelParams = lib.mkAfter [ "audit=0" ]` to `hosts/vpn-server/configuration.nix` to suppress the Oracle ARM kernel's broken audit subsystem. Replaced deprecated `nixfmt-classic` with `nixfmt`. Added `zsh.shellInit` sourcing of `hm-session-vars.sh` so `sessionPath` and `sessionVariables` are available in non-login shells.

**2026-05-21 (evening)** — dbus-broker transition completed on all five hosts. Root cause of resistance identified: `nix-flatpak` bundles its own older nixpkgs (`da5ad661`) that still defaults `dbus.implementation` to `"dbus"` via `mkDefault`, silently winning over nixpkgs-unstable's newer `mkDefault "broker"`. Fix: added an explicit (non-default) `services.dbus.implementation = "broker"` in `security.nix`; this plain assignment beats all `mkDefault` values regardless of source. Removed `server` host placeholder from `flake.nix` and `hosts/server/` — no physical hardware exists; will be re-added via `/new-host` when hardware arrives. Added `home.sessionPath = [ "$HOME/.local/bin" ]` to `dotfiles/bosko/bosko-claude.nix` so the native claude-code binary at `~/.local/bin/claude` is discoverable in PATH after rebuild.

**2026-05-21 (continued)** — nixpkgs channel split complete. Added `nixpkgs-stable` input (`nixos-25.05`) to `flake.nix`; server and vpn-server now pin to the stable channel while desktop hosts remain on `nixos-unstable`. vpn-server deployed via remote rebuild and confirmed running `25.05.20260102.ac62194 (Warbler)` with all three WireGuard peers intact. Stale VPN private-key pending items removed from docs — all clients have been fully operational since 2026-05-20. M-9 milestone complete.

**2026-05-21** — CLAUDE.md documentation audit: corrected natty's user permissions (she is wheel/sudo and a Nix trusted user, same as bosko); removed `virtualisation` from the `desktopModules` description (it is gaming-only); added `disko` to vpn-server module composition; fixed the directory layout tree. Added five new skills: `diff-generations` (nix store diff-closures between generations), `flake-check` (validate flake across all five hosts), `journal` (tail journald locally or via SSH), `nix-repl` (print repl invocation with host-specific starters), and `fmt` (alejandra/nixpkgs-fmt fallback for changed .nix files). Skill library now at 22 skills.

**2026-05-20** — Claude Code skill library completed. 18 project-local skills now live under `.claude/skills/`. The second build session added: `ssh-host` (short-name SSH resolver), `remote-rebuild` (headless deployment via `nixos-rebuild switch --target-host` to vpn-server or server), `rollback` (generation listing + confirm + `switch --rollback`), `search-pkg` (`nix search nixpkgs` wrapper with add-package nudge), `new-host` (interactive scaffolder for desktop/server/remote-arm host types with correct template per type), and `pin-input` (flake input pinning to a rev/tag — lock-only or permanent, with home-manager/disko follow-input warnings). The first build session earlier the same day added `nixos-dry-run`, `nixos-rebuild`, `nixos-gc`, `vpn-status`, `new-module`, `commit`, `push`, `update`, `add-package`, `add-flatpak`, `switch-de`, and `new-peer`. agenix for secret management was evaluated and deferred — VPN keys live at `/etc/wireguard/private.key` on each host and are never in the repo. _(Superseded 2026-06-15: secrets are now managed with sops-nix — see the [Secrets](#secrets) section and the 2026-06-15 entry.)_

**2026-05-18** — WireGuard VPN fully deployed. Oracle Cloud ARM vpn-server is live on its public endpoint; `wg0` active on the tunnel subnet with three configured peers (gaming, laptop, natalie-laptop). Shared `dotfiles/common/modules/vpn.nix` client module created with full-tunnel routing, DNS override (`1.1.1.1 8.8.8.8`), and `persistentKeepalive = 25`. Per-host VPN addresses configured in `hosts/*/networking.nix`. ARM build target fixed for `server-rebuild` alias (now builds natively on the server). binfmt aarch64 emulation added to gaming as offline fallback. natalie-laptop added as fourth WireGuard peer with real keys. `gh` added to common system packages.

**2026-05-17** — Inlined the Starship prompt configuration from an external `starship.toml` into a native `programs.starship.settings` attrset in `shell.nix`; removed the `xdg.configFile` symlink and deleted the TOML file. Fixed Nerd Font v3 symbol spacing for 9 language/tool glyphs in the inline config. Disabled auto-format globally across all Helix language configurations. Routine flake inputs bump (`lutris` openldap regression still unresolved upstream). Deleted stale `dotfiles/vpn/` directory (NordVPN remnants). Added `tmux` to gaming system packages.

**2026-05-15** — Repository layout restructured: host-specific directories moved from `dotfiles/<hostname>/` to a top-level `hosts/<hostname>/` directory; bosko-specific HM configs moved from `dotfiles/common/configs/` to `dotfiles/bosko/`. All `flake.nix` paths updated; dry-run passed cleanly.

**2026-05-12 to 2026-05-14** — Housekeeping and preparation for the gaming AMD card swap. `nvidia.nix` removed from `desktopModules` and added explicitly per-host (gaming, laptop, natalie-laptop) — dropping NVIDIA from gaming now requires only a one-line change in `flake.nix`. `claude-code` and `gemini-cli` consolidated into `users.users.bosko.packages` in `users.nix` (removed from per-host environment files). `mumble` moved from `users.nix` to `gaming/environment.nix` (gaming-only). `rebuild` alias changed from `nh os switch` to `nh os boot`. `cleanup` retention reduced from 5 to 3 builds. `home-manager.nix` refactored into a single nested block; natty's HM config now correctly imports `home.nix`. `discord` removed from gaming and laptop (vesktop is the replacement). `obs-studio` removed from laptop and natalie-laptop. Various natalie-laptop package list cleanups. `qdirstat` added to shell packages. Flake inputs bumped. `natalie-laptop` installed and running with Cosmic DE verified.

**2026-05-12** — `natalie-laptop` host config completed with real `hardware-configuration.nix` (Intel CPU, NVMe root, vfat /boot). Commented out `lutris` in `gaming.nix` to unblock `nh os boot`; `lutris` transitively requires `openldap-2.6.13/i686-linux` with no binary cache entry in nixpkgs-unstable. `faugus-launcher` covers the immediate need. Added `pnpm` to gaming. `rebuild` alias changed from `nh os switch` to `nh os boot`.

**2026-05-11** — Added `natalie-laptop` host (Cosmic DE, `natty` user restored without elevated privileges). Deleted `vpn.nix` (unused; to be rewritten when VPN is imminent). Fixed `audit-rules-nixos.service` activation failure by disabling the service via `lib.mkForce false` while keeping `auditd` running. Scoped `amd.nix` to gaming only. Fixed xwayland duplication in `niri.nix`. Added `dry-run` alias.

**2026-05-10 (evening)** — Pinned `services.dbus.implementation = lib.mkDefault "dbus"` in `security.nix` to prevent boot failure from nixpkgs-unstable's silent default change to dbus-broker (rev `4bd9165`, 2026-04-14). Laptop `nh os switch` completed successfully — first live switch since the 2026-05-06 security audit.

**2026-05-10** — Removed `bottles` from emulation.nix (unused). Moved `gaming.nix` out of `desktopModules` into the gaming host's own module list. Fixed nixpkgs-unstable breaking change: `programs.swaylock` and `services.swayidle` migrated from system scope to `home-manager.users.bosko` in `niri.nix`.

**2026-05-06** — Full security audit remediation. Replaced plaintext password with SHA-512 hash; recreated `security.nix` in `commonModules`; removed user `natty`; disabled SSH password auth on gaming and laptop; set `homeMode = "0700"`; bound qBittorrent to `127.0.0.1`; closed Steam remote-access firewall ports; replaced ntpd with chrony on all hosts; replaced NetworkManager with DHCP on server; restricted Avahi to virbr0; added swaylock/swayidle to laptop; removed php, nmap, and netcat; added `.gitignore`; fixed gaming boot `fmask`.

## Roadmap

- Apply rebuild + reboot on laptop and natalie-laptop: activate managed Claude Code policy, natalie-laptop DE switch to Plasma, FinanceGuru, and package consolidation changes; remove hand-maintained `~/.ssh/config` on each host afterward
- Interface-scope Avahi mDNS: replace `openFirewall = true` in `printing.nix` with per-interface rules restricting UDP 5353 to the LAN interface
- AMD card swap on gaming: remove `nvidia.nix` from gaming's module list when card is physically replaced
- Harden vpn-server further (AppArmor profiles, fail2ban, rate-limiting on UDP 51820)
- Re-add `server` host via `/new-host` skill when physical hardware is available; pin to `nixpkgs-stable` following the vpn-server pattern

## License

Personal configuration — no formal license.
