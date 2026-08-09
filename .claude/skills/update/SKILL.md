---
name: update
description: Triggers when user says "update flake", "update inputs", "nix flake update", "update nixpkgs", "update all inputs", or "run flake update". Runs nix flake update and shows a readable summary of what changed in flake.lock.
model: haiku
version: 0.2.0
---

# Flake Update Workflow

Update all flake inputs for `/home/bosko/NixOS` and present a human-readable summary of what changed. Do not commit or rebuild automatically — leave those to the user.

## Step 0 — Check for an active pin before updating

A temporary pin set via `/pin-input` (lock-file only, `flake.nix`'s `url` is untouched) has no
dedicated marker file — `nix flake update` will silently re-resolve it to the latest rev with
no warning of its own, undoing the pin. The one live record of "is anything intentionally held
back right now" is the most recent `flake-update-verify` loop memory file (that loop tracks
pins it hits or sets across runs):

```bash
latest=$(ls -t /home/bosko/NixOS/.claude/loops/flake-update-verify/memory-*.md 2>/dev/null | head -1)
[ -n "$latest" ] && grep -iA3 "pin" "$latest"
```

If it mentions an active pin (e.g. "Pin is TEMPORARY... the next full/bare `nix flake update`
... WILL try to move `<input>` again"), surface that note to the user and confirm via the
**AskUserQuestion tool** — options **Proceed and un-pin `<input>`** / **Skip this update** —
before running Step 1. If nothing mentions a pin, proceed straight to Step 1.

## Step 1 — Run the update

```bash
nix flake update --flake /home/bosko/NixOS
```

Always use `--flake /home/bosko/NixOS` — do not rely on the current working directory, since this skill may be invoked from anywhere.

This command will take a minute or two while Nix fetches the latest revisions for all inputs. Stream the output to the user so they can see progress.

## Step 2 — Display the diff

After the update completes, run the shared lock-diff script and present its output verbatim:

```bash
/home/bosko/NixOS/.claude/lib/flake-lock-diff.sh
```

It compares the committed `flake.lock` (`HEAD:flake.lock`) against the now-updated working-tree `flake.lock` and prints one aligned line per changed root input:

```
Updated inputs:
  nixpkgs          a1b2c3d4 -> e5f6a7b8   (2026-05-19)
  home-manager     11223344 -> 55667788   (2026-05-18)
  nix-flatpak      aabbccdd -> eeff0011   (2026-05-17)
```

Each line is `<name>  <old8> -> <new8>  (<YYYY-MM-DD from new lastModified>)`. Inputs whose `rev` did not change are omitted automatically, and `follows`-only inputs are skipped gracefully.

If the script prints `flake.lock unchanged.` (nothing updated), tell the user:

> All inputs are already up to date — flake.lock was not modified.

## Step 3 — Remind the user of next steps

After presenting the diff summary, always end with:

> When you are ready:
> - Run `/nixos-dry-run` to preview what the updated inputs would change in your system build.
> - Run `/commit` to commit the updated `flake.lock` once you are satisfied.

Do not run either of those automatically — leave them to the user.

---

## Shared script

The lock-diff summary is produced by `/home/bosko/NixOS/.claude/lib/flake-lock-diff.sh`, shared with `/bump-input` and `/pin-input`. It diffs the committed `flake.lock` against the working tree (optional `$1` git ref overrides the OLD side) and prints aligned `name  old8 -> new8  (date)` lines, or `flake.lock unchanged.`. Do not re-derive the parse in prose — call the script.

## Key constraints

- Always use `--flake /home/bosko/NixOS` with `nix flake update`. Never rely on cwd.
- Do not auto-commit `flake.lock` — committing is the user's explicit action via `/commit`.
- Do not auto-rebuild or auto-dry-run — suggest it, do not invoke it.
- Do not use `git add` after the update — flake.lock will appear as a modification to an already-tracked file; staging is handled by `/commit`.
- The `Co-Authored-By` trailer is not needed here — it belongs only in commit messages.
- If `nix flake update` fails (network error, evaluation error), show the full error output and do not proceed to the diff step.
