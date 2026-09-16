# Writing/editing a global skill in a Home-Manager-managed repo

Load this when scope is **Global** and the repo is Home-Manager-managed — detect it: `dotfiles/bosko/bosko-claude.nix` and `dotfiles/bosko/claude/skills/` both exist (equivalently, `~/.claude/skills/*/SKILL.md` resolve into `/nix/store` — they're read-only symlinks).

## The ownership model

The global Claude Code skills are **owned by this repo**, not by `~/.claude`. Source lives in `dotfiles/bosko/claude/skills/<name>/SKILL.md`; `dotfiles/bosko/bosko-claude.nix` symlinks each one into `~/.claude/skills/<name>/SKILL.md` via Home Manager `home.file`.

- **Always edit the repo copy** under `dotfiles/bosko/claude/skills/`. The `~/.claude/skills/` path is a read-only `/nix/store` symlink — editing it directly is impossible, and the change wouldn't survive a rebuild anyway.
- A new skill must be added to the `home.file` list in `bosko-claude.nix`, then rebuilt before its symlink appears.
- Edits to an existing skill's `SKILL.md` only take effect in `~/.claude` after a rebuild (`nh os boot /home/bosko/NixOS`); the live session keeps using the old store path until then.

## Writing a brand-new global skill

When managed, **do NOT write to `~/.claude/skills/`** — that path is read-only and an untracked file there is wiped on the next rebuild. Instead:

1. Write the SKILL.md (and, if it needs one, `scripts/<name>.sh` and/or `references/<topic>.md`) to `dotfiles/bosko/claude/skills/<name>/`.
2. Add a `home.file` entry to `dotfiles/bosko/bosko-claude.nix`. If the skill has (or is likely to grow) `scripts/`/`assets/`/`references/` files, prefer a **recursive** directory entry from the start — mirroring the several existing global skills already using `recursive = true` (grep `bosko-claude.nix` for the pattern) — so a sibling file added later needs no further wiring. **This is not optional for a skill with any sibling file**: a file-by-file entry (only `SKILL.md`) silently leaves that sibling invisible to `~/.claude` even after a rebuild — found for real 2026-09-16, when `research`, `agent-suggestion`, and `improve-system` each turned out to be wired file-by-file and had to be converted after gaining a `references/` dir.
   ```nix
   ".claude/skills/<name>" = {
     source = "${self}/dotfiles/bosko/claude/skills/<name>";
     recursive = true;
     force = true;
   };
   ```
   Otherwise (a plain single-file skill, no `scripts/`/`assets/`), use the simpler file-by-file form:
   ```nix
   ".claude/skills/<name>/SKILL.md" = {
     source = "${self}/dotfiles/bosko/claude/skills/<name>/SKILL.md";
     force = true;
   };
   ```
3. `git add dotfiles/bosko/claude/skills/<name>/ dotfiles/bosko/bosko-claude.nix` — flake evaluation only sees tracked files, so the new file(s) must be staged before a dry-run/rebuild.
4. Optionally run `nh os boot /home/bosko/NixOS --dry` (or the `nixos-dry-run` skill) to confirm the config still evaluates. The `~/.claude/skills/<name>/` symlink appears only **after** a real rebuild (`nh os boot /home/bosko/NixOS`).
