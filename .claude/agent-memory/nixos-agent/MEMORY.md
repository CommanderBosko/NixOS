# Memory Index

- [audit-rules-nixos blank-line bug workaround](feedback_audit_rules_empty.md) — security.audit.rules must be non-empty or audit-4.1.2-unstable fails; keep the comment sentinel in security.nix
- [dbus-broker default change in nixpkgs unstable](project_dbus_broker_default.md) — nixpkgs rev 4bd9165 (2026-04-14) changed dbus implementation default to "broker"; triggers switch inhibitor; boot failure risk
