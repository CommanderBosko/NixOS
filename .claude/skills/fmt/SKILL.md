---
name: fmt
description: Use this skill when the user wants to "format nix files", "fmt", "run formatter", "format changed files", "alejandra", or "nixpkgs-fmt". Formats all changed .nix files using alejandra (or nixpkgs-fmt as fallback) before committing.
version: 0.1.0
---

# Format Changed Nix Files

Detect which `.nix` files have been modified or are untracked, then run the formatter over them. Keeps the repo consistently formatted before committing.

## Step 1 — Find changed .nix files

Run both in parallel:

```bash
git -C /home/bosko/NixOS diff --name-only HEAD -- '*.nix'
git -C /home/bosko/NixOS ls-files --others --exclude-standard -- '*.nix'
```

The first command finds modified tracked files. The second finds untracked (new) `.nix` files.

Combine both lists, deduplicate, and convert to absolute paths by prepending `/home/bosko/NixOS/`.

If no `.nix` files are changed or untracked, report:

> No changed .nix files to format.

And stop.

## Step 2 — Detect the formatter

Check which formatter is available:

```bash
which alejandra 2>/dev/null || which nixpkgs-fmt 2>/dev/null || echo "none"
```

- **Prefer `alejandra`** — it is the formatter used in this repo.
- Fall back to `nixpkgs-fmt` if alejandra is not on PATH.
- If neither is available, report the error:

> Neither `alejandra` nor `nixpkgs-fmt` found on PATH.
> Install one with: `nix run nixpkgs#alejandra -- <files>` or add it to your system packages.

Then stop — do not attempt to format without a known formatter.

## Step 3 — Run the formatter

Run the formatter on all changed files at once:

### alejandra

```bash
alejandra <file1> <file2> ...
```

### nixpkgs-fmt

```bash
nixpkgs-fmt <file1> <file2> ...
```

Pass all changed files as arguments in a single invocation.

## Step 4 — Report results

After the formatter runs, check which files actually changed:

```bash
git -C /home/bosko/NixOS diff --name-only -- '*.nix'
```

Report the outcome:

- If files were reformatted, list them:
  ```
  Formatted 3 file(s) with alejandra:
    dotfiles/common/modules/security.nix
    hosts/gaming/environment.nix
    dotfiles/common/configs/home.nix
  ```
- If no files changed (formatter was a no-op), say:
  ```
  All changed .nix files were already correctly formatted.
  ```

## Step 5 — Suggest next steps

If files were reformatted, remind the user to stage the formatting changes before committing:

> Files have been formatted. Stage them with the `commit` skill or manually with:
> `git -C /home/bosko/NixOS add <files>`

---

## Key facts

- Working directory is always `/home/bosko/NixOS`.
- `alejandra` formats in-place and exits 0 on success.
- `nixpkgs-fmt` also formats in-place.
- Only format files that are actually changed — do not run the formatter across the entire repo unless the user explicitly asks.
- Formatting changes are cosmetic and safe; they do not alter Nix semantics.
