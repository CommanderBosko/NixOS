---
name: shared-module-check
description: Use this skill when the user asks "did this break other hosts", "check shared module impact", "does this break vpn-server too", "cross-host check", or "verify this commonModules change". Forces a full 4-host deep-eval sweep after editing a file shared across hosts, since a local dry-run silently verifies nothing about the other hosts.
---

# Shared Module Check

Catch cross-host breakage from editing a file shared across multiple NixOS hosts — a local `dry-run`/`flake-check` only exercises the host you're actually on and silently verifies nothing about the others. (Bucket: Verification)

## Why this exists

`commonModules` and `desktopModules` in `flake.nix` compose every host from the same shared files. Editing one of them (or `flake.nix` itself) can break a host you never touched directly and never ran a local check against. This isn't hypothetical: `deep-eval-check`'s own history includes a 2026-07-02 pnpm/vesktop insecure-package regression that a shallow `flake-check` missed, and on 2026-07-18 an `rtk` package reference added to `modules/users.nix` broke `vpn-server`'s evaluation entirely (it pins `nixpkgs-25.11` stable on `aarch64-linux`, where the package didn't exist yet) — uncaught because the commit that introduced it only exercised the local (unstable, x86_64) host. This skill closes that gap by making the cross-host sweep the default next step after any shared-file edit, not an optional afterthought.

## Arguments

Parse from the user's request:

- **File/target** (optional) — a specific changed file to check directly, e.g. "does editing `modules/security.nix` break other hosts?". If given, use it directly in Step 2 and skip inferring from git. If omitted, resolve changed files from `git diff` per Step 1.

## Steps

### 1. Resolve which files changed

Run `git -C /home/bosko/NixOS diff --name-only` (uncommitted changes) — also check `git -C /home/bosko/NixOS diff --name-only HEAD~1` or a wider range if the user is asking about an already-committed change. If the user names a specific file directly, use that instead of inferring from git.

### 2. Check whether any changed file is shared

For each changed file, run:

```bash
bash /home/bosko/NixOS/.claude/lib/classify-shared-file.sh <file>
```

It reads `flake.nix` live and prints `SHARED: <reason>` or `LOCAL` — never hardcode a copy of the module lists yourself. A file counts as shared not just when it's listed inside the `commonModules`/`desktopModules` array bodies, but also when it's wired directly into 2+ hosts' own per-host module lists without going through either named array (e.g. `modules/desktop-environments/niri.nix`, imported directly by `gaming` and `natalie-laptop`'s host blocks and via `laptopModules` for `laptop` — none of which route through `desktopModules`). A plain membership check against just the two named arrays misses exactly this case.

- **If nothing shared changed** (every result is `LOCAL`) — say so plainly and stop. No sweep needed; a local `nixos-dry-run` or `de-smoke-check` (for a DE module the classifier reports `LOCAL` because no host currently imports it at all) is the right tool instead.
- **If any changed file classifies as `SHARED`** — proceed to Step 3.

### 3. Run the 4-host sweep

```bash
bash /home/bosko/NixOS/.claude/skills/deep-eval-check/scripts/deep-eval-check.sh
```

This deep-evaluates `gaming`, `laptop`, `natalie-laptop`, and `vpn-server`'s full build graphs — not just a shallow "is it a derivation" check.

### 4. Report per-host PASS/FAIL

Same convention as `deep-eval-check`: PASS with the `.drv` path, or FAIL with the full error output verbatim (don't summarize away the exact broken line).

### 5. On any FAIL, check for a channel/arch availability gap first

Before assuming something else broke: `vpn-server` pins `nixpkgs-25.11` (stable) on `aarch64-linux`, while the three desktop hosts track `nixpkgs-unstable` on `x86_64-linux`. A package or option that only exists on unstable will break `vpn-server` specifically, and nowhere else.

If the error is `undefined variable '<pkg>'` (or similarly, a missing attribute) on `vpn-server` alone while the desktop hosts pass — this is almost certainly the availability gap, not a real bug. The fix: gate the reference on the package's actual existence rather than hardcoding it:

```nix
pkgs.lib.optional (pkgs ? <attrName>) pkgs.<attrName>
```

This self-heals once a future stable point-release backports the package — no manual re-edit needed. Reference precedent: `modules/users.nix` and `modules/claude-code.nix`'s `rtk` guard (fixed 2026-07-18) — cite this file pair as the concrete example when suggesting the fix. If a hook or config elsewhere *uses* the gated package (e.g. a script that shells out to it), gate that reference too, the same way — an ungated caller will fail at runtime even if the package reference itself is fixed.

If the failure isn't an availability gap (a real syntax error, a genuinely broken option, an assertion failure), diagnose it normally — don't force the availability-gap explanation onto an unrelated bug.

### 6. Don't clear the change until all 4 hosts pass

Re-run Step 3 after any fix. Only report the change as safe to commit/dry-run/rebuild once `gaming`, `laptop`, `natalie-laptop`, and `vpn-server` all PASS.

## Report

Tell the user:
- Which file(s) triggered the check (or that none did, and the sweep was skipped)
- The per-host PASS/FAIL table
- If a fix was suggested or applied, one line pointing at the `pkgs ? <attrName>` guard pattern and which files it touched

## Scripts

- `.claude/lib/classify-shared-file.sh <file>` — read-only classifier (Step 2). Reads `flake.nix` live and prints `SHARED: <reason>` or `LOCAL`; shared by `ship-nix-change` too so the classification logic only lives in one place.

## Key facts

- Read-only through Step 4 — evaluation only, never builds or activates. Step 5's fix (if needed) is the only step that edits files.
- This is the shared-file counterpart to `de-smoke-check` (unwired DE modules) and the mandatory pre-`fleet-rollout` gate that `deep-eval-check` already documents — this skill just adds the trigger discipline of *always* reaching for the 4-host sweep specifically when a shared file changed, instead of leaving that judgment call to memory.
- Working directory: `/home/bosko/NixOS`.

## Gotchas

- **A plain membership check against the two named arrays (`commonModules`/`desktopModules`) misses a module wired directly into 2+ hosts' own per-host module lists.** Found 2026-09-04 via `skill-audit`: `modules/desktop-environments/niri.nix` is imported directly by `gaming`'s and `natalie-laptop`'s host blocks (and via `laptopModules` for `laptop`) — three hosts — without ever appearing in `desktopModules`, so the old Step 2 test silently skipped the 4-host sweep for the one DE module actually in production use. Fixed by routing Step 2 through `classify-shared-file.sh`, which also checks for direct multi-host references, not just array membership.
