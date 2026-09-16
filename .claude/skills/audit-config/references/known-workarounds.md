# Known Intentional Workarounds (do NOT flag these as bugs)

Load this before flagging a security/hardening finding — cross-check every candidate finding against this list and against the project's memory files before reporting.

This repo has deliberate, documented deviations. Flagging them as findings is noise.

- **AppArmor PAM path workaround** (`modules/security.nix`): SDDM `include`
  directives are not `.so` paths. The `lib.mkForce` clearing of `rules` for `sddm` /
  `sddm-autologin`, with `text` overrides using `pkgs.linux-pam`, is **intentional** — it works
  around a nixpkgs bug. Not a finding.
- **Audit rules loader disabled**: `systemd.services.audit-rules-nixos.enable = lib.mkForce false;`
  works around a blank-line parse error in the rules loader (audit-4.1.2); `auditd` itself still
  runs for AppArmor logging. This is **intentional**, not a silently-disabled audit daemon. Not a
  finding.
- **`nvidia.nix` imported per-host, not via `desktopModules`**: intentional, so gaming can drop it
  for the AMD card. Not a structural smell.
- **dbus-broker via plain assignment** (not `mkDefault`) in security.nix: intentional, beats
  nix-flatpak's `mkDefault`. Not a finding.
- Anything already explained in `CLAUDE.md` or the memory index at
  `/home/bosko/.claude/projects/-home-bosko-NixOS/memory/MEMORY.md`.

When in doubt whether something is intentional, read the relevant memory file before reporting it.
