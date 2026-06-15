# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-06-15 (session 4, continued) — Post-sops skills + fwupd ESP fix

**Focus**: Tooling and follow-ups after the sops/public work — NixOS skills for the new secrets setup, plus fixing gaming's fwupd ESP detection.

### What changed (and why)
- Built three project-local skills: `add-secret` (sops add/edit/rotate), `fleet-status` (read-only health sweep of all hosts), `secret-scan` (tree + full-history leak scan). Both scripts tested; secret-scan reports clean across 776 commits.
- Upgraded `new-host` to register a new host as a sops recipient — closes a footgun where a scaffolded host couldn't decrypt the shared password secrets.
- Reworked the `session-closer` skill toward curating `project-state.md`/README over exhaustive logging, and rotated the 28-entry log (kept ~5 active, archived the rest in `session-summary-archive.md`).
- Fixed fwupd ESP detection in `firmware.nix`: gaming's ESP has the wrong partition type code, so the old `[fwupd] EspLocation` (wrong config section) was ignored — switched to `uefiCapsuleSettings.OverrideESPMountPoint`. Eval-clean on all four hosts.

### Decisions
- fwupd: declarative `OverrideESPMountPoint` override (non-destructive) over relabeling the partition type on disk.
- New skills are project-local (`.claude/skills/`), not global — they're NixOS-specific.

### Issues / surprises
- Two `fleet-status` bugs caught by actually running it (the `●` status glyph parsed as a unit name; a wrong reboot-vs-staged comparison) — fixed before commit.
- `EspLocation` and `OverrideESPMountPoint` both exist in fwupd 2.1.4 but in different sections; only the `[uefi_capsule]` one is read by the capsule plugin.

### Next session
- Rebuild each host to activate the fwupd fix; verify on gaming with `sudo fwupdtool esp-list` (should list the ESP) and a clean `fwupd-refresh`.
- The rebuild also activates the reworked `session-closer` skill in `~/.claude`.
- Optional: the second disk (`sda`) GRUB may be probing via `useOSProber` — investigate if an extra boot entry appears.

**Commits**: `f929196..1555a2d` (3 commits)

---

## Session: 2026-06-15 (session 4) — Make the repo public via sops-nix secrets

**Duration Estimate**: ~1.5 hours
**Session Focus**: Make the NixOS config repository public without exposing any sensitive data — by migrating in-repo secrets to sops-nix and scrubbing history.

### What Was Accomplished

- **Full-repo secret scan** — identified the one true in-repo secret (the `bosko`/`natty` `$6$` password hashes in `users.nix`) plus judgment-call items (Oracle endpoint IP, SSH/WG public keys, LAN IPs, UUIDs). Confirmed WG **private** keys were already out of the repo (`/etc/wireguard/private.key`).
- **Adopted sops-nix** — added the flake input, `dotfiles/common/modules/sops.nix` (in `commonModules`), and `.sops.yaml`. Each host's age recipient key is derived from its existing SSH ed25519 host key via `ssh-to-age`; a personal admin age key was generated at `~/.config/sops/age/keys.txt` (kept out of repo).
- **Encrypted secrets committed** — `secrets/common.yaml` (both password hashes, `neededForUsers`) encrypted to admin + all hosts; `secrets/hosts/<host>.yaml` (each host's WG private key) encrypted to admin + that host only.
- **Rewired consumers** — `users.nix` → `hashedPasswordFile`; `vpn.nix` and `hosts/vpn-server/configuration.nix` → `privateKeyFile = config.sops.secrets."wg-private-key".path`.
- **Verified identity-preserving** — decrypted each WG private key and confirmed its derived pubkey matches the server's registered peer (all 4 MATCH) before any rebuild.
- **Rebuilt + verified all four hosts** — vpn-server first (canary, passwordless sudo, done over SSH), then gaming/laptop/natalie-laptop (user-run, password sudo). Confirmed via server-side `wg show`: live handshakes on every peer within seconds of each rebuild; `sudo`/login intact everywhere.
- **History rewrite** — `git filter-repo --replace-text` purged both plaintext hashes from all commits (183 occurrences → 0), force-pushed, and realigned the laptop/natalie clones. A pre-rewrite backup bundle is at `~/nixos-pre-sops-rewrite.bundle` (local only).
- **Documented + published** — added a "Secrets" section to `README.md`, fixed the VPN bullets, superseded the old "agenix deferred" note, then flipped the repo **public** (`gh repo edit … --visibility public`) after a final clean scan.

### Files Changed

- `flake.nix`, `flake.lock` — sops-nix input; `sops.nix` added to `commonModules`
- `dotfiles/common/modules/sops.nix` — new; imports sops-nix module, declares shared password secrets
- `.sops.yaml` — new; recipient map (admin + 4 host age keys)
- `secrets/common.yaml`, `secrets/hosts/{gaming,laptop,natalie-laptop,vpn-server}.yaml` — new; encrypted
- `dotfiles/common/modules/users.nix` — `hashedPassword` → `hashedPasswordFile`
- `dotfiles/common/modules/vpn.nix`, `hosts/vpn-server/configuration.nix` — `privateKeyFile` → sops path
- `README.md` — new Secrets section, VPN bullet fixes, changelog entries

### Commits This Session

- `a2c2a52` — feat(sops): manage password hashes and WireGuard keys with sops-nix
- `ab1396d` — docs(readme): document sops-nix secrets setup
- `af330e2` — docs(readme): mark the 2026-05-20 agenix-deferred note as superseded

### Decisions Made

- **sops-nix over `hashedPasswordFile`-only** — chosen for a self-contained, reproducible public repo (secrets encrypted in-repo) rather than just removing them.
- **Migrate WG private keys too** (reproducibility) but **leave the endpoint IP in-repo** — it's a public internet endpoint, not a secret, and hiding it (a build-time wg-quick string) would add a VPN failure-mode for no real gain.
- **Rewrite history** rather than rotate passwords — purges the old hashes from the public-bound history directly.
- **Per-host least privilege** — each WG key encrypted only to its own host + admin, not shared.

### Issues Encountered

- **Desktop sudo blocks non-interactive ops** — the three desktops require a sudo password, so their WG-key reads and rebuilds had to be user-run in a real terminal (the `!` prefix has no tty for sudo). vpn-server's passwordless sudo let it be driven fully over SSH.
- **`ssh -t` merged sudo's prompt into the captured key file** — handled by extracting the 43-char base64 key with a regex and validating each before encrypting.
- **`gh` not authenticated** — `git push` works via SSH key, but the visibility flip needed `gh auth login` (user ran it).

### Remaining / Next Session

- **Back up `~/.config/sops/age/keys.txt`** (admin key) and **delete `~/nixos-pre-sops-rewrite.bundle`** once confident (it contains the old hashes).
- Optional: rotate the two login passwords for belt-and-suspenders (not required — history is clean).
- Carried over from prior sessions: rebuild+reboot laptop and natalie-laptop to activate the managed Claude Code policy / Plasma switch; activate SDDM auto-login disable on gaming; interface-scope Avahi mDNS in `printing.nix`.

---

**Duration Estimate**: ~15 minutes
**Session Focus**: Replace the one-shot `~/.claude/trim-after-managed.sh` script (deleted earlier today) with a permanent, per-rebuild-automatic declarative solution in `bosko-claude.nix`.

### What Was Accomplished

- **`home.activation.trimClaudeSettings` added to `dotfiles/bosko/bosko-claude.nix`** — Home Manager activation script that, on every rebuild, checks whether `/etc/claude-code/managed-settings.json` exists, and if so, uses `jq` to strip `permissions.deny`, `permissions.ask`, and `hooks` from `~/.claude/settings.json` while leaving `permissions.allow`, `model`, and `enabledPlugins` intact. The file stays writable so interactive `/model` and plugin toggles persist across sessions. Idempotent: if the target keys are already absent, `jq -e` exits non-zero and the trim is skipped. No-op until the managed file exists.
- **Module signature updated** — `{ self, ... }` changed to `{ self, pkgs, lib, ... }` to bring in `pkgs.jq`, `pkgs.coreutils`, and `lib.hm.dag`.
- **Replaces the deleted one-shot trim script** — `~/.claude/trim-after-managed.sh` was deleted earlier this session after running successfully on gaming. This activation script provides the same cleanup automatically on all future rebuilds.
- **Scoped to bosko only** — Lives in `dotfiles/bosko/bosko-claude.nix`, which natty does not import. If natty ever starts using Claude Code, the trim logic can be added for her then.
- **Verified via dry-run** — `nh os boot . --dry` evaluated cleanly; activation-script node present in the build graph. jq logic unit-tested for both the no-op case (already-clean file) and the trim case (keys present and correctly removed).

### Files Changed

- `dotfiles/bosko/bosko-claude.nix` — updated module signature; added `home.activation.trimClaudeSettings` (24 lines)

### Commits This Session

- `af831b6` — feat(bosko): replace trim script with declarative HM activation script

### Decisions Made

- **HM activation script over a systemd service or login hook** — Activation runs in the correct user context, is guaranteed to execute on every generation switch, and integrates cleanly with the HM DAG (`entryAfter [ "writeBoundary" ]`). No separate unit file needed.
- **Scoped to bosko only** — natty does not use Claude Code; no managed file exists for her. Adding the trim logic to a shared module would be premature.
- **`jq -e` for the conditional check** — Skips temp-file creation and `mv` entirely when the file is already clean, avoiding spurious writes to `settings.json`.

### Issues Encountered

None. Dry-run clean; jq logic verified for both the no-op and trim paths.

### Remaining / Next Session

- **Apply rebuild + reboot on gaming** — activates the new trim activation script and the SDDM auto-login disable committed 2026-06-03; trim will also run automatically on all future rebuilds.
- **Apply rebuild + reboot on laptop** — activates managed Claude Code policy, package consolidation, and other pending changes.
- **Apply rebuild + reboot on natalie-laptop** — activates DE switch to Plasma, managed Claude Code policy, FinanceGuru, and other pending changes.
- **Interface-scope Avahi mDNS firewall** — replace `openFirewall = true` in `printing.nix` with per-interface rules restricting UDP 5353 to the LAN interface.
- **AMD card swap on gaming** — when the physical card arrives, remove `nvidia.nix` from gaming's module list.

---

## Session: 2026-06-09 — Claude Code managed policy activated; personal settings trimmed

**Duration Estimate**: ~30 minutes
**Session Focus**: Activate the NixOS-managed Claude Code policy deployed in the previous session, verify it was live, then trim the now-redundant duplicate rules from the personal `~/.claude/settings.json`.

### What Was Accomplished

- **Rebuilt and rebooted to activate the managed Claude Code policy** — The `dotfiles/common/modules/claude-code.nix` module (committed as `92e0358`) deploys `/etc/claude-code/managed-settings.json` system-wide via `environment.etc`. After rebooting, confirmed the managed file was present and active.
- **Ran `~/.claude/trim-after-managed.sh`** — The trim script removed from `~/.claude/settings.json` all permission rules (deny/ask) and the fork bomb `PreToolUse` hook that were now redundant, because those same rules are enforced at the system level via the managed file. The personal settings file now contains only personal preferences: the `allow` permission list, `enabledPlugins`, and `model`.
- **Backup saved** — The pre-trim settings were backed up to `~/.claude/settings.json.bak.1781041160` before modification.
- **Trim script deleted** — The one-shot trim script was deleted per the user's request after successful execution.

### Files Changed

All changes were outside the git repo:

- `~/.claude/settings.json` — trimmed: deny/ask permission rules and fork bomb hook removed; only personal prefs remain
- `~/.claude/settings.json.bak.1781041160` — backup of pre-trim settings (created by trim script)
- `~/.claude/trim-after-managed.sh` — deleted after use

### Commits This Session

None. The repo was clean at session start. All work was on files outside `/home/bosko/NixOS`.

### Decisions Made

- **Personal settings file should only hold personal preferences** — Now that deny/ask rules and the fork bomb hook are enforced at the system level (via the managed file that applies to all users on all rebuilt hosts), duplicating them in the personal file adds maintenance noise. The managed file takes precedence and cannot be overridden by the personal file, so the personal copies were vestigial.
- **Trim script is single-use** — Once applied, there is no reason to keep the script. Deleted to keep `~/.claude/` clean.

### Issues Encountered

None. The managed file was present and correctly formatted after the reboot. The trim script ran cleanly.

### Remaining / Next Session

- **Apply rebuilds on laptop and natalie-laptop** — to deploy the managed Claude Code policy on those hosts.
- **Apply rebuilds on desktop hosts** — gaming (activates auto-login disable), laptop, and natalie-laptop; remove hand-maintained `~/.ssh/config` on each host afterward.
- **Interface-scope Avahi mDNS firewall** — replace `openFirewall = true` in `printing.nix` with per-interface rules restricting UDP 5353 to the LAN interface.
- **AMD card swap on gaming** — when the physical card arrives, remove `nvidia.nix` from gaming's module list; run `rebuild` and reboot.
- **Re-enable `lutris` on gaming** — once `openldap-2.6.13-i686-linux` has a binary cache entry in nixpkgs-unstable.

---

## Session: 2026-06-09 (earlier) — Managed Claude Code policy; natty gets gemini-cli; package consolidation

**Duration Estimate**: ~1.5 hours
**Session Focus**: Deploy a NixOS-managed Claude Code settings file that enforces security policy globally across all hosts, add gemini-cli for the natty user, and consolidate common packages from per-host environment files into the shared shell module.

### What Was Accomplished

- **`dotfiles/common/modules/claude-code.nix` created** — New NixOS module that deploys `/etc/claude-code/managed-settings.json` via `environment.etc`. The managed file encodes deny rules for destructive commands (`rm -rf`, `mkfs`, `dd`, etc.), ask rules for sensitive operations (`git push --force`, `sudo` commands, etc.), and a `PreToolUse` fork bomb guard using `jq` pinned to its Nix store path so it resolves regardless of `PATH`. Added to `commonModules` in `flake.nix` so all five hosts share the enforced, tamper-resistant policy. Managed settings layer over each user's writable `~/.claude/settings.json`; users cannot override managed rules.
- **`gemini-cli` added to natty's user packages** — `pkgs.gemini-cli` added to `users.users.natty.packages` in `dotfiles/common/modules/users.nix`, mirroring bosko's existing package.
- **Package consolidation into `shell.nix`** — `nodejs`, `pnpm`, and `p7zip` moved out of per-host `environment.nix` files (gaming, laptop, natalie-laptop) and into `dotfiles/common/modules/shell.nix` `systemPackages`. `jq` also added. These now apply consistently across all hosts instead of being duplicated.
- **Flake inputs bumped** — Four `flake.lock` updates (2026-06-07 and 2026-06-09) bumped nixpkgs-unstable, home-manager, nix-flatpak, and other inputs.

### Files Changed

- `dotfiles/common/modules/claude-code.nix` — new; 101-line module deploying managed-settings.json with deny/ask rules and fork bomb hook
- `flake.nix` — added `claude-code.nix` to `commonModules` list
- `dotfiles/common/modules/users.nix` — added `pkgs.gemini-cli` to `users.users.natty.packages`
- `dotfiles/common/modules/shell.nix` — added `jq`, `nodejs`, `pnpm`, `p7zip` to `systemPackages`
- `hosts/gaming/environment.nix` — removed `nodejs`, `pnpm`, `p7zip` (now in shell.nix)
- `hosts/laptop/environment.nix` — removed `nodejs`, `pnpm` (now in shell.nix)
- `hosts/natalie-laptop/environment.nix` — removed `p7zip` (now in shell.nix)
- `flake.lock` — updated inputs (four bump commits)

### Commits This Session

- `26635e4` — refactor(packages): consolidate node toolchain, jq, p7zip into shell.nix
- `8105995` — feat(users): add gemini-cli to natty's user packages
- `92e0358` — feat(claude-code): enforce Claude Code policy via managed settings
- `1870d93` — Revert "chore(memory): add nixos-agent memory to repo for cross-machine sharing"
- `b3ba202` — chore(memory): add nixos-agent memory to repo for cross-machine sharing
- `fbddcb0`, `f6ef70a`, `1bf7d9c`, `24efd1f` — flake lock bumps (2026-06-07 – 2026-06-09)

### Decisions Made

- **`jq` pinned to its Nix store path in managed-settings.json** — The `PreToolUse` fork bomb hook runs in a restricted environment where `$PATH` may not include `jq`. Interpolating the absolute store path at build time ensures the hook resolves regardless of shell environment.
- **Managed settings via `environment.etc`** — Using `environment.etc."claude-code/managed-settings.json".text` generates the file at activation time from the Nix expression. The file content is always in sync with the flake; no manual file management needed.
- **Package consolidation to `shell.nix` `commonModules`** — `nodejs`, `pnpm`, and `p7zip` are general-purpose tools useful on any machine. Moving them removes three-way duplication and ensures consistency across hosts.

### Issues Encountered

None. All three substantive commits built cleanly.

### Remaining / Next Session

- **Rebuild and reboot to activate managed policy** — until then, the personal settings still have the old redundant rules.
- **Trim personal `~/.claude/settings.json`** — after confirming the managed file is active, run `~/.claude/trim-after-managed.sh` to remove duplicate rules.
- **Apply rebuilds on other desktop hosts** (laptop, natalie-laptop) to deploy the managed policy there too.

---

## Session: 2026-06-05 — natalie-laptop switches to Plasma; FinanceGuru integrated; krohnkite shared; lutris re-enabled

**Duration Estimate**: ~2 hours
**Session Focus**: Switch natalie-laptop from Cosmic to Plasma 6, integrate the FinanceGuru personal finance app as a desktop package, clean up the krohnkite tiling configuration, and re-enable lutris now that the upstream openldap regression is resolved.

### What Was Accomplished

- **natalie-laptop DE switched to Plasma** — Changed the imported DE module from `cosmic.nix` to `plasma.nix` in natalie-laptop's flake entry in `flake.nix`. `krohnkite` (KWin tiling script) added to `hosts/natalie-laptop/environment.nix`.
- **krohnkite moved to shared `plasma.nix`** — `krohnkite` extracted from `hosts/natalie-laptop/environment.nix` and added to `dotfiles/common/modules/desktop-environments/plasma.nix` `systemPackages`, so all Plasma hosts (gaming and natalie-laptop) get it automatically. Package list sorted.
- **FinanceGuru added to desktop hosts** — `financeguru` wired as a flake input (`github:CommanderBosko/FinanceGuru`), installed via `environment.systemPackages` on gaming, laptop, and natalie-laptop. URL first set to `path:` (local) then corrected to `github:` (public repo). Later removed from laptop — not needed there. flake pin bumped to include Stock Tips and Debt Snowball tabs.
- **lutris re-enabled on gaming** — `gaming.nix` updated to un-comment `lutris`; `flake.lock` bumped to a nixpkgs-unstable rev that includes the binary cache entry for `openldap-2.6.13-i686-linux`. The months-long workaround is resolved.

### Files Changed

- `flake.nix` — switched natalie-laptop DE to `plasma.nix`; added `financeguru` input; added package to three hosts; then removed from laptop
- `flake.lock` — added financeguru lock entry; bumped nixpkgs-unstable (lutris fix)
- `hosts/natalie-laptop/environment.nix` — krohnkite added then removed (moved to plasma.nix)
- `dotfiles/common/modules/desktop-environments/plasma.nix` — added krohnkite to systemPackages; sorted package list
- `hosts/gaming/environment.nix` — added financeguru package
- `hosts/laptop/environment.nix` — added then removed financeguru package
- `dotfiles/common/modules/gaming.nix` — un-commented `lutris`

### Commits This Session

- `b73640b` — refactor(plasma): move krohnkite to shared plasma.nix, sort packages
- `d33a148` — feat(natalie-laptop): switch DE to Plasma and add krohnkite
- `c7e2b30` — chore: remove FinanceGuru from laptop, bump flake pin
- `fc37146` — chore: switch financeguru input to public GitHub URL
- `d83951a` — feat: add FinanceGuru to all desktop hosts
- `f62dc5f` — updated flake and lutris is working again

### Decisions Made

- **natalie-laptop on Plasma** — Switched from Cosmic to Plasma 6 to align with the gaming host's DE and share krohnkite tiling configuration without per-host duplication.
- **krohnkite in shared `plasma.nix`** — Any host using Plasma should get the tiling script; keeping it per-host would require duplication for each future Plasma host.
- **FinanceGuru removed from laptop** — The personal finance app is best used on the primary desktop (gaming) and natalie-laptop; not needed on the laptop.
- **lutris re-enabled** — The upstream `openldap-2.6.13-i686-linux` binary cache regression that blocked `lutris` for several months has been resolved in nixpkgs-unstable.

### Issues Encountered

None. All commits applied cleanly.

### Remaining / Next Session

- **Apply rebuild + reboot on natalie-laptop** — activate DE switch to Plasma and FinanceGuru installation.
- **Apply rebuild on gaming** — activate lutris and FinanceGuru.
- **AMD card swap on gaming** — remove `nvidia.nix` when physical card arrives.

---

## Session: 2026-06-03 — Security audit and hardening: root SSH disabled, auto-login removed

**Duration Estimate**: ~3 hours (single commit session)
**Session Focus**: Run a multi-agent security review of the full NixOS flake, identify real findings, remediate two of three, and deploy the vpn-server change immediately to confirm the new deploy path (bosko + passwordless sudo) works end-to-end.

### What Was Accomplished

- **Full security audit completed** — Multi-agent review across all six security domains: users/SSH, kernel hardening, networking/firewall, desktop environments, gaming/VFIO. Three real findings were identified; two remediated this session.
- **Fixed: root SSH login on vpn-server** — Changed `PermitRootLogin` from `"prohibit-password"` to `"no"` in `hosts/vpn-server/configuration.nix`. Added `security.sudo.wheelNeedsPassword = false` so `nixos-rebuild --use-remote-sudo` can operate non-interactively as bosko over SSH without stalling on a password prompt.
- **Fixed: SDDM auto-login on gaming** — Changed `autoLogin.enable` from `true` to `false` in `hosts/gaming/environment.nix`. Physical access to the gaming machine no longer drops directly into an unauthenticated desktop session.
- **Updated remote-rebuild skill** — All `root@150.136.232.63` references in `.claude/skills/remote-rebuild/SKILL.md` changed to `bosko@150.136.232.63`; troubleshooting notes updated accordingly.
- **Cosmetic improvement to users.nix** — Added `# Desktop` / `# Laptop` inline comments to the SSH authorized keys block in `dotfiles/common/modules/users.nix` (only unstaged change at session start).
- **Deployed to vpn-server** — Used a transitional `root@` deploy (the last time root SSH would work) to push the change that disables root SSH. Post-deploy verification: root SSH is now blocked, `bosko` passwordless sudo confirmed working.
- **Found but deferred: Avahi mDNS `openFirewall = true`** — `dotfiles/common/modules/printing.nix:12` exposes UDP 5353 on all interfaces. Left unfixed because closing it would break printer discovery. Proper fix is interface-scoped firewall rules; deferred to a future session.

### Files Changed

- `hosts/vpn-server/configuration.nix` — `PermitRootLogin = "no"` (was `"prohibit-password"`); added `security.sudo.wheelNeedsPassword = false`
- `hosts/gaming/environment.nix` — `autoLogin.enable = false` (was `true`)
- `.claude/skills/remote-rebuild/SKILL.md` — updated all deploy targets from `root@150.136.232.63` to `bosko@150.136.232.63`
- `dotfiles/common/modules/users.nix` — added `# Desktop` / `# Laptop` inline comments to authorized_keys block

### Commits This Session

- `cb6105d` — fix(security): disable root SSH on vpn-server and auto-login on gaming

### Decisions Made

- **`PermitRootLogin = "no"` over `"prohibit-password"` on an internet-facing host** — The vpn-server is directly reachable on the public internet (TCP 22 open). `"prohibit-password"` still permits key-based root login, which presents an elevated-privilege attack surface. Removing root SSH entirely and using `bosko` with passwordless sudo is strictly more secure; the deploy path works identically in practice.
- **Passwordless sudo on vpn-server is acceptable** — The only accounts on the server are root and bosko; bosko requires SSH key auth to reach the machine. An attacker who can SSH as bosko already has the key material needed to be dangerous. `wheelNeedsPassword = false` exists solely to enable non-interactive remote deploys over batch SSH sessions.
- **Avahi `openFirewall` left as-is** — Interface-scoped firewall rules are the correct fix but require testing to avoid breaking mDNS discovery on the LAN interface. Deferred rather than risking printer discovery breakage on all three desktop hosts.
- **Auto-login disabled on gaming** — Physical access to the gaming machine is not as controlled as a server rack. Requiring a login credential adds a meaningful barrier for an unattended session.

### Issues Encountered

- None. The security audit, remediation commits, and vpn-server deploy all completed cleanly on the first attempt.

### Remaining / Next Session

- **Avahi `openFirewall` interface scoping** — `dotfiles/common/modules/printing.nix:12`: implement per-interface firewall rules to restrict UDP 5353 to the LAN interface only rather than all interfaces.
- **Apply rebuilds on desktop hosts** — run `rebuild` + reboot on gaming, laptop, and natalie-laptop to activate the auto-login change (gaming) and other pending config changes.
- **AMD card swap on gaming** — when the physical card arrives, remove `nvidia.nix` from gaming's module list in `flake.nix`; run `rebuild` in terminal and reboot.
- **Re-enable lutris on gaming** — once nixpkgs-unstable ships a binary cache entry for `openldap-2.6.13-i686-linux`, uncomment `lutris` in `gaming.nix`.

---

