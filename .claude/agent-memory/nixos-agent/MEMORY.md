# Memory Index

- [audit-rules-nixos blank-line bug workaround](feedback_audit_rules_empty.md) — security.audit.rules must be non-empty or audit-4.1.2-unstable fails; keep the comment sentinel in security.nix
- [audit option distinction: .enable vs auditd.enable](feedback_audit_option_distinction.md) — security.audit.enable (rules loader, default false) vs security.auditd.enable (daemon, set true in security.nix); wrong one = no-op closure
- [dbus-broker default change in nixpkgs unstable](project_dbus_broker_default.md) — natalie-laptop pending final reboot; explicit broker setting now in security.nix (nix-flatpak unpinned nixpkgs was the blocker)
- [nix-flatpak unpinned nixpkgs silently overrides defaults](feedback_nix_flatpak_unpinned_nixpkgs.md) — nix-flatpak injects older NixOS module defaults; never rely on upstream mkDefault taking effect passively
- [WireGuard VPN setup — Oracle Cloud ARM](project_vpn_setup.md) — DEPLOYED and working; full-tunnel routing confirmed; natalie-laptop peer placeholder removed to unblock wg0 service
