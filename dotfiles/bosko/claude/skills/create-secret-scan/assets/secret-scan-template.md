This asset is the contract for the project-local secret-scan skill that create-secret-scan
generates. Everything between `<!-- BEGIN -->` and `<!-- END -->` is the file content —
substitute every `<…>` placeholder from the interview and write the result to
`<repo-root>/.claude/skills/secret-scan/SKILL.md`.

<!-- BEGIN -->
---
name: secret-scan
description: Triggers when the user says "secret scan", "scan for secrets", "check for leaked secrets", "is it safe to push", "any secrets in the repo", or "pre-public check". Read-only scan of the working tree and full git history for plaintext secrets, tuned to this project's <SCHEME_LABEL> setup.
model: haiku
version: 0.1.0
---

# Secret Scan

A read-only guard that scans the **working tree and full git history** for plaintext
secrets before a push or before changing repo visibility.

## Arguments

None.

## What it knows about this project

- **Secret-management scheme:** <SCHEME_DESCRIPTION>
- **Encrypted/managed secret locations:** <ENCRYPTED_LOCATIONS_NOTE>
- **Paths excluded from pattern matching:** <EXCLUDED_PATHS_NOTE>
- **Known intentional non-secrets (don't flag these):** <KNOWN_NON_SECRETS_NOTE>
- **Full git-history scan:** <HISTORY_SCAN_NOTE>

## Instructions

1. Run `scripts/secret-scan.sh`. It performs four passes:
   - **Working tree** — high-signal patterns (private-key blocks, password hashes,
     GitHub/AWS/Slack tokens<EXTRA_PATTERNS_NOTE>) across tracked files, excluding the
     configured paths.
   - **Encrypted-secret integrity** — <ENCRYPTED_INTEGRITY_INSTRUCTION>
   - **Git history** — the same high-signal patterns across *all commits* (catches
     secrets that were committed then removed but still live in history). Prints
     `commit:path` hits. <HISTORY_SCAN_INSTRUCTION>
   - **.gitignore coverage** — informational check that common secret-file extensions
     are ignored.

2. Report the result. If **clean**, say so plainly. If there are findings, present each
   with its location and the right remediation:
   - **Plaintext secret in the working tree** → <REMEDIATION_PLAINTEXT>
   - **Unencrypted managed-secret file** → <REMEDIATION_UNENCRYPTED>
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
- To add a new secret pattern, edit `EXTRA_PATTERNS` in `scripts/secret-scan.sh`.

## Script

```
scripts/secret-scan.sh
```
<!-- END -->
