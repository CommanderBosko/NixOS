# Skill Audit — Implementing Fixes

Load this when the user says "fix it" (or picks **Implement now** in Step 4). Implement in priority order:

- Work highest-priority first; **commit at phase boundaries** so each lands cleanly.
- **Verify empirically as you go** — run the scripts you extract (read-only paths), `bash -n` every script, and prove drift fixes against the live system. Don't guess at a value you can test.
- Re-derive drift-prone data **live** rather than re-hardcoding it (enumerate inputs/DE modules from the tree; resolve hosts from the shared config).
- For NixOS repos: after touching anything the flake evaluates (or a symlinked global skill), run a dry-run (`nixos-dry-run`) to certify it still evaluates. Project-local `.claude/` changes don't affect the flake.
- Adding a **new global skill** (or new sibling files for one) needs no Nix wiring — `claude-hm/files.nix` auto-links every skill directory recursively — only a `git add` (the flake sees tracked files only) + a rebuild before it appears in `~/.claude`. (The old file-by-file-entry pitfall, where only `SKILL.md` got linked, has been gone since 2026-09-16.)
