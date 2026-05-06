---
name: audit-rules-nixos blank-line bug workaround
description: audit-4.1.2-unstable rejects blank lines in audit.rules; security.audit.rules must be non-empty
type: feedback
---

`security.audit.rules` must always contain at least one entry. In nixpkgs 26.05pre-git, `auditd.nix` sets `security.audit.enable = lib.mkDefault true` when `security.auditd.enable = true`. The `audit.nix` module generates `audit.rules` using `lib.concatLines cfg.rules`; when `cfg.rules = []`, `lib.concatLines []` returns `""` which leaves a blank line between `-r 0` and `-e 1` in the rules file.

`audit-4.1.2-unstable-2025-09-06` treats blank lines as parse errors (`There was an error in line 2 of audit.rules`), causing `audit-rules-nixos.service` to fail on every activation.

**Why:** `auditctl` historically allowed blank lines, but 4.1.2-unstable introduced stricter parsing. Combined with the new 26.05 auditd.nix implicitly enabling `security.audit`, empty-rules configs became broken.

**How to apply:** Keep `security.audit.rules = [ "# NixOS managed audit configuration" ];` in `security.nix`. A `#` comment is a valid no-op `auditctl` rule that prevents the empty-list code path. Do not remove this or reset `security.audit.rules` to `[]`.
