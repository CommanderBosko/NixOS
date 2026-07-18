---
name: secret-scan
description: Triggers when the user says "secret scan", "scan for secrets", "check for leaked secrets", "is it safe to push", "any secrets in the repo", or "pre-public check". Read-only scan of the working tree and full git history for plaintext secrets, tuned to this repo's sops setup.
model: haiku
version: 0.1.0
---

# Secret Scan

A read-only guard that scans the **working tree and full git history** for plaintext
secrets before a push or before changing repo visibility. This is the reusable form of the
pre-publish check done during the sops migration.

**Distinct from `audit-config`:** `audit-config` reviews configuration *correctness and
security posture*; `secret-scan` looks for *leaked secret material* (private keys, password
hashes, tokens) that should never be committed in plaintext.

## Arguments

None.

## What it knows about this repo

- **`secrets/`** holds sops-**encrypted** files — expected, not flagged. The scan instead
  verifies each is genuinely encrypted (a `secrets/*.yaml` missing the `sops:`/`ENC[`
  markers would be an accidental plaintext commit — that IS flagged).
- **`.claude/skills/`** is excluded from pattern matching because skill docs (including this
  one) legitimately contain example secret strings.
- **Intentional non-secrets are not flagged:** the WireGuard endpoint IP `150.136.232.63`
  and all SSH/WireGuard *public* keys are public by nature.

## Instructions

1. Run `scripts/secret-scan.sh`. It performs four passes:
   - **Working tree** — high-signal patterns (private-key blocks, age secret keys, unix
     password hashes, inline WireGuard private keys, GitHub/AWS tokens) across tracked
     files, excluding `secrets/` and `.claude/skills/`.
   - **sops integrity** — every `secrets/*.yaml` must contain `ENC[` and a `sops:` block.
   - **Git history** — the worst patterns across *all commits* (catches secrets that were
     committed then removed but still live in history). Prints `commit:path` hits.
   - **.gitignore coverage** — informational check for `*.key`, `*.pem`, `*.age`, `.env`.

2. Report the result. If **clean**, say so plainly. If there are findings, present each
   with its location and the right remediation:
   - **Plaintext secret in the working tree** → move it into sops (`add-secret` skill) and
     replace the reference with `config.sops.secrets."…".path`.
   - **Unencrypted `secrets/*.yaml`** → encrypt it: `sops -e -i <file>` (it likely got
     committed before encryption).
   - **Secret found in history** (but not the tree) → it was removed but persists in past
     commits. Removing it now is **not** enough for a public repo — rewrite history with
     `git filter-repo --replace-text` (replace the literal with a redaction marker), then
     force-push, then realign other clones (`git fetch && git reset --hard origin/main`).
     Consider rotating the leaked credential regardless.

3. The history pass scans every commit, so on a large repo it can take a little time — tell
   the user it's working if it pauses.

## Notes

- Purely read-only; never modifies files or git state.
- Pattern-based, so it's a strong guard, not a proof of absence. Treat a clean result as
  "no high-signal leaks found," and still apply judgment for project-specific secrets.
- To add a new secret pattern, edit the pattern list in `scripts/secret-scan.sh`.

## Script

```
scripts/secret-scan.sh
```
