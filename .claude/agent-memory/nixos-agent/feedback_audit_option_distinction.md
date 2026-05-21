---
name: audit-option-distinction
description: security.audit.enable vs security.auditd.enable are distinct NixOS options; confusing them produces no-op changes
type: feedback
---

`security.audit.enable` and `security.auditd.enable` are two different NixOS options:

- `security.audit.enable` — controls the NixOS-managed audit rules loader (`audit-rules-nixos.service`). Defaults to `false` already. Setting `lib.mkForce false` here is a no-op if security.nix doesn't set it to true.
- `security.auditd.enable` — controls the `auditd.service` daemon itself. This is what `security.nix` sets to `true` (for AppArmor logging).

**Why:** When trying to silence audit on vpn-server (ARM kernel with no audit support), the wrong option was targeted first. `security.audit.enable = lib.mkForce false` produced an identical closure (no-op, already false). The correct fix is `security.auditd.enable = lib.mkForce false`.

**How to apply:** Any time a task says "disable audit on X host", use `security.auditd.enable = lib.mkForce false` in that host's config. The no-op test is: if the closure hash doesn't change after your edit, you targeted the wrong option.

See also: [[dbus-broker-default-change]] for the related logind/dbus issue during `nixos-rebuild switch` over SSH.
