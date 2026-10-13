# Secret Scan — history remediation

Load this when the history pass (pass 3) reports a hit that is no longer in the working tree.

**Secret found in history** (but not the tree) → it was removed but persists in past
commits. Removing it now is **not** enough for a public repo — rewrite history with
`git filter-repo --replace-text` (replace the literal with a redaction marker), then
force-push, then realign other clones (`git fetch && git reset --hard origin/main`).
Consider rotating the leaked credential regardless.
