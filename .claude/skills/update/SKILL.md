---
name: update
description: Triggers when user says "update flake", "update inputs", "nix flake update", "update nixpkgs", "update all inputs", or "run flake update". Runs nix flake update and shows a readable summary of what changed in flake.lock.
version: 0.1.0
---

# Flake Update Workflow

Update all flake inputs for `/home/bosko/NixOS` and present a human-readable summary of what changed. Do not commit or rebuild automatically — leave those to the user.

## Step 1 — Capture the current lock state

Before running the update, snapshot the current `flake.lock` so you can diff against it after:

```bash
git -C /home/bosko/NixOS stash list
git -C /home/bosko/NixOS diff flake.lock
```

Also note the current HEAD so you know the baseline:

```bash
git -C /home/bosko/NixOS log --oneline -1
```

## Step 2 — Run the update

```bash
nix flake update --flake /home/bosko/NixOS
```

Always use `--flake /home/bosko/NixOS` — do not rely on the current working directory, since this skill may be invoked from anywhere.

This command will take a minute or two while Nix fetches the latest revisions for all inputs. Stream the output to the user so they can see progress.

## Step 3 — Parse and display the diff

After the update completes, get the raw diff:

```bash
git -C /home/bosko/NixOS diff flake.lock
```

Parse the diff and present a clean, human-readable summary. For each input that changed, extract and display:

- **Input name** (e.g. `nixpkgs`, `home-manager`, `nix-flatpak`)
- **Old rev** — first 8 characters of the previous `narHash` or `rev` field
- **New rev** — first 8 characters of the updated `rev` field
- **Last modified** — the `lastModified` timestamp converted to a readable date (YYYY-MM-DD) if present in the lock entry

Format the summary as a list like this:

```
Updated inputs:
  nixpkgs          a1b2c3d4 → e5f6g7h8  (2026-05-19)
  home-manager     11223344 → 55667788  (2026-05-18)
  nix-flatpak      aabbccdd → eeff0011  (2026-05-17)
```

If an input's `rev` did not change (same hash before and after), omit it from the list — it did not update.

If **nothing changed** (the diff is empty), tell the user:

> All inputs are already up to date — flake.lock was not modified.

## Step 4 — Remind the user of next steps

After presenting the diff summary, always end with:

> When you are ready:
> - Run `/nixos-dry-run` to preview what the updated inputs would change in your system build.
> - Run `/commit` to commit the updated `flake.lock` once you are satisfied.

Do not run either of those automatically — leave them to the user.

---

## Key constraints

- Always use `--flake /home/bosko/NixOS` with `nix flake update`. Never rely on cwd.
- Do not auto-commit `flake.lock` — committing is the user's explicit action via `/commit`.
- Do not auto-rebuild or auto-dry-run — suggest it, do not invoke it.
- Do not use `git add` after the update — flake.lock will appear as a modification to an already-tracked file; staging is handled by `/commit`.
- The `Co-Authored-By` trailer is not needed here — it belongs only in commit messages.
- If `nix flake update` fails (network error, evaluation error), show the full error output and do not proceed to the diff step.
