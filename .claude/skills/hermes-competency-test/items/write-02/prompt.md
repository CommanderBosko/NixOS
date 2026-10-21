A friend sent me `task/change.diff`, a change to their own homelab NixOS flake (not this repo, so don't try to apply or build it here). Write the pull request description for it and save it to `task/out/pr.md`.

Format:

1. Line 1 is the PR title as a conventional commit: `type(scope): description`, lowercase after the colon, no trailing period, under 72 characters. Plain text, no leading `#`.
2. Then these three sections, in this order:
   - `## Summary`: two or three sentences on what the change does and why.
   - `## Changes`: a bullet list that names the path of every file the diff touches.
   - `## Testing`: how this was or should be verified.

Describe only what the diff actually does. Don't change `task/change.diff`.
