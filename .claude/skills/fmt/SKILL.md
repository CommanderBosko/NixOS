---
name: fmt
description: Use this skill when the user wants to "format nix files", "fmt", "run formatter", "format changed files", "alejandra", or "nixpkgs-fmt". Formats all changed .nix files using alejandra (or nixpkgs-fmt as fallback) before committing.
model: haiku
version: 0.2.0
---

# Format Changed Nix Files

Detect modified/untracked `.nix` files and run the repo's formatter over them. Keeps the repo consistently formatted before committing.

## Step 1 — Run the format script

```bash
.claude/skills/fmt/scripts/fmt-changed.sh
```

The script collects changed (`git diff --name-only HEAD`) and untracked (`git ls-files --others`) `.nix` files, deduplicates, picks `alejandra` (falling back to `nixpkgs-fmt`), formats them in place, and prints which files ended up reformatted. Exit codes:
- `0` — formatted, or nothing to do (it prints "No changed .nix files to format." or "already correctly formatted").
- `1` — no formatter on PATH; relay its hint (`nix run nixpkgs#alejandra -- <files>`).

## Step 2 — Report and suggest next steps

Relay the script's summary. If files were reformatted, remind the user to stage them before committing:

> Files have been formatted. Stage them with the `git-commit` skill or:
> `git -C /home/bosko/NixOS add <files>`

If nothing changed, say the changed `.nix` files were already correctly formatted.

---

## Script

```
scripts/fmt-changed.sh
```

## Key facts

- Working directory is always `/home/bosko/NixOS`. `alejandra` is the repo's formatter (`nixpkgs-fmt` is the fallback); both format in place.
- Only changed/untracked files are touched — never the whole repo.
- Formatting is cosmetic and safe; it does not alter Nix semantics.
