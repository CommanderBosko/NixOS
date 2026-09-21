# Writing/editing a global skill in a Home-Manager-managed repo

Load this when scope is **Global** and the repo is Home-Manager-managed — detect it: `dotfiles/bosko/bosko-claude.nix` and `dotfiles/bosko/claude/skills/` both exist (equivalently, `~/.claude/skills/*/SKILL.md` resolve into `/nix/store` — they're read-only symlinks).

## The ownership model

The global Claude Code skills are **owned by this repo**, not by `~/.claude`. Source lives in `dotfiles/bosko/claude/skills/<name>/SKILL.md`; `dotfiles/bosko/claude-hm/files.nix` (imported by `bosko-claude.nix`) auto-discovers every subdirectory of `skills/` via `builtins.readDir` and symlinks each one into `~/.claude/skills/<name>` as a recursive directory link, so `scripts/`, `assets/` and `references/` files ride along automatically. Custom agents (`dotfiles/bosko/claude/agents/<name>.md`) are auto-linked the same way.

- **Always edit the repo copy** under `dotfiles/bosko/claude/skills/`. The `~/.claude/skills/` path is a read-only `/nix/store` symlink — editing it directly is impossible, and the change wouldn't survive a rebuild anyway.
- A new skill needs **no Nix wiring** — there is no entry to add. It only needs to be `git add`ed (flake evaluation sees tracked files only; an untracked skill silently doesn't appear) and the config rebuilt before its symlink appears.
- Edits to an existing skill's `SKILL.md` (or a new file under its `scripts/`/`assets/`/`references/`) only take effect in `~/.claude` after a rebuild (`nh os boot /home/bosko/NixOS`); the live session keeps using the old store path until then.

## Writing a brand-new global skill

When managed, **do NOT write to `~/.claude/skills/`** — that path is read-only and an untracked file there is wiped on the next rebuild. Instead:

1. Write the SKILL.md (and, if it needs one, `scripts/<name>.sh` and/or `references/<topic>.md`) to `dotfiles/bosko/claude/skills/<name>/`.
2. `git add dotfiles/bosko/claude/skills/<name>/` — flake evaluation only sees tracked files, so the new file(s) must be staged before a dry-run/rebuild. No `bosko-claude.nix`/`files.nix` edit is needed; every skill directory is a recursive dir link, so there is no single-file vs. recursive distinction to choose between.
3. Optionally run `nh os boot /home/bosko/NixOS --dry` (or the `nixos-dry-run` skill) to confirm the config still evaluates. The `~/.claude/skills/<name>/` symlink appears only **after** a real rebuild (`nh os boot /home/bosko/NixOS`).
