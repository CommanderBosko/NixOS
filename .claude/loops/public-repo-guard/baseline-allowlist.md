# public-repo-guard — baseline allowlist

Accepted, known-intentional findings. The loop reads this at start and treats anything
listed here as NOT a genuine finding. Add to it only with explicit approval (Training
Mode ON). Each entry: what it is, where, and why it's safe.

## Accepted

- **sops-encrypted ciphertext is expected, not a leak** — `secrets/*.yaml` and any
  sops-managed files contain AES-encrypted blobs + age recipients, never plaintext. A
  scanner flagging "high-entropy string" inside a sops file is a false positive. Genuine
  finding = plaintext secret OUTSIDE the sops envelope. See [[project_sops_secrets]].
- **fwupd "ESP not detected" warning on gaming** — intentional/unfixable via config (MBR
  type 0x0c, no LVFS, Secure Boot off). Not a security gap. See [[project_fwupd_esp]].
- **AppArmor SDDM PAM `text` overrides (`security.nix`)** — `lib.mkForce` clearing the
  `rules` attrset for `sddm`/`sddm-autologin` is a deliberate nixpkgs-bug workaround that
  preserves identical PAM behaviour, not a weakening. See CLAUDE.md Security Module.
- **`security.audit.rules` comment sentinel** — a non-empty rules list with only a comment
  is a deliberate workaround for an audit-4.1.2 blank-line parse error. See
  [[feedback_audit_rules_empty]].
- **Repo is intentionally public** — flipped public 2026-06-15 after history purge; the
  guard exists *because* it's public. Public-ness itself is not a finding.
