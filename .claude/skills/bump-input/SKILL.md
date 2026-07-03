---
name: bump-input
description: Triggers when user says "bump an input", "bump <input>", "update just nixpkgs", "update one input", "bump financeguru", "update a single flake input", or "move <input> to latest". Bumps a single named flake input to its latest upstream revision and shows the lock diff — without touching the other inputs.
version: 0.2.0
---

# Bump Single Flake Input

Bump exactly **one** named flake input for `/home/bosko/NixOS` to its latest upstream revision and show what changed. This is the single-input counterpart to `/update` (all inputs) and the opposite of `/pin-input` (hold an input back). Do not commit or rebuild automatically — leave those to the user.

(Bucket: Data Enrichment — pulls the latest upstream revision of one input in.)

## Arguments

This skill is driven by a single input:

- **input name** — the root flake input to bump (e.g. `nixpkgs`, `financeguru`, `dms`). If supplied in the user's prompt, match it case-insensitively against the live input list (Step 1) and skip the question. If omitted, ask which input via the AskUserQuestion tool, offering the live input names as options.

## Step 1 — Resolve which input

The root inputs live in `flake.nix`. List them live rather than trusting a hardcoded list, using
the shared helper (also used by `/pin-input`):

```bash
/home/bosko/NixOS/.claude/lib/list-flake-inputs.sh
```

- If the user named an input (e.g. "bump financeguru"), match it case-insensitively against that list and use the exact node name.
- If they didn't name one, present the live list and ask which to bump via the **AskUserQuestion tool**, with one option per enumerated input name.
- If the named input isn't in the list, say so and show the available names — do not guess.

Note: inputs with `inputs.nixpkgs.follows = "nixpkgs"` (e.g. `home-manager`, `disko`) track `nixpkgs`'s revision. Bumping `nixpkgs` moves what those inputs see; bumping a follower on its own only moves that follower's own sources. Mention this when the user bumps `nixpkgs`.

## Step 2 — Snapshot the baseline

```bash
git -C /home/bosko/NixOS diff flake.lock
git -C /home/bosko/NixOS log --oneline -1
```

If `flake.lock` already has uncommitted changes, tell the user before proceeding — the post-bump diff will include those too.

## Step 3 — Bump the one input

```bash
nix flake lock --update-input <name> --flake /home/bosko/NixOS
```

Always pass `--flake /home/bosko/NixOS`; never rely on cwd, since this skill may be invoked from anywhere. This resolves the input's original URL to its latest upstream rev and rewrites only that input's node in `flake.lock`.

If the command fails (network error, evaluation error), show the full output and stop — do not proceed to the diff.

## Step 4 — Show the diff

Run the shared lock-diff script and present its output:

```bash
/home/bosko/NixOS/.claude/lib/flake-lock-diff.sh
```

Because only the one input was bumped (assuming the lock was otherwise clean — see Step 2), the script prints a single aligned line for it:

```
Bumped: financeguru
  financeguru   a1b2c3d4 -> e5f6a7b8   (2026-06-23)
```

The line format is `<name>  <old8> -> <new8>  (<YYYY-MM-DD from new lastModified>)`.

If the script prints `flake.lock unchanged.`, tell the user:

> <name> was already at its latest revision — flake.lock was not modified.

## Step 5 — Remind of next steps

Close with:

> When you are ready:
> - Run `/nixos-dry-run` to preview what the bumped input would change in your system build.
> - Run `/commit` to commit the updated `flake.lock`.

Do not run either automatically.

---

## Shared scripts

- The lock diff is rendered by `/home/bosko/NixOS/.claude/lib/flake-lock-diff.sh`, shared with `/update` and `/pin-input`. It diffs the committed `flake.lock` against the working tree (optional `$1` git ref overrides the OLD side) and prints aligned `name  old8 -> new8  (date)` lines, or `flake.lock unchanged.`. Do not hand-roll the rev/date parse — call the script.
- The input list is rendered by `/home/bosko/NixOS/.claude/lib/list-flake-inputs.sh`, shared with `/pin-input`. Do not hand-roll the `nix flake metadata` parse — call the script.

## Key constraints

- Bump exactly one input. To bump everything, that's `/update`; to hold one back, that's `/pin-input`.
- Always use `--flake /home/bosko/NixOS` — never rely on cwd.
- Never edit `flake.nix` — only `flake.lock` changes.
- Do not auto-commit, `git add`, or auto-rebuild — suggest, don't invoke.
- No `Co-Authored-By` trailer here — that belongs only in commit messages.
- When bumping `nixpkgs`, note the `home-manager` / `disko` follows dependency.

## Gotchas

- **`nix flake lock --update-input <name>` no longer exists** (observed 2026-07-02): current nix rejects both `--update-input` (removed deprecated alias) and `--flake` on that subcommand. Use `nix flake update <name> --flake /home/bosko/NixOS` instead.
