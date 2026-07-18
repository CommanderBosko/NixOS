---
name: de-smoke-check
description: Use this skill when the user wants to "de-smoke check", "check if this DE module still evaluates", "deep-eval this desktop environment", "verify <name> DE module", or "smoke-test this desktop environment". Deep-evaluates a single desktop-environment module via lib.deSmoke — the only real way to verify a DE module that isn't currently imported by any host.
model: haiku
version: 0.1.0
---

# De-Smoke Check

Force Nix to fully evaluate one named module under `modules/desktop-environments/` via `lib.deSmoke`, catching real eval errors in a module that no host currently wires in. (Bucket: Verification)

## Why this exists

Only 3 of the 12 modules under `modules/desktop-environments/` are actually imported by a host (`niri` on gaming/laptop, `plasma` on natalie-laptop) — the other 9 are edited only through `lib.deSmoke`, the laptop config with each DE module swapped in. `nh os boot --dry` on a real host only exercises whatever DE that host already has wired in; it silently verifies nothing about an unwired module you just touched. `nix flake check` is also insufficient here — like the four real hosts, it's a shallow check. This skill closes both gaps for the unwired case.

## Arguments

Parse from the user's request:

- **Module name** (optional) — the DE module under `modules/desktop-environments/` to check, e.g. `omarchy`, `hyprland`. If omitted, resolve it per Step 1 (infer from recent changes, or list and ask).

## Step 1 — Identify the target module

Resolve which DE module to check, in this order:
1. If the user named it explicitly (e.g. "check omarchy"), use that name.
2. Otherwise, check `git status`/`git diff` for recently modified files under `modules/desktop-environments/` and infer the name from the filename (minus `.nix`).
3. If still ambiguous, list the available names (relative to this skill's directory) and ask:
   ```bash
   scripts/de-smoke-check.sh
   ```

## Step 2 — Deep-evaluate the module's build graph

```bash
scripts/de-smoke-check.sh <name>
```

This forces full evaluation of the laptop config with `<name>` swapped in as the DE — not just a shallow "is it a derivation" check. Allow up to 5 minutes (300000ms timeout). The script prints `PASS: <drv>` on success or `FAIL:` followed by the full error output on failure.

## Step 3 — Report the result

- **Pass** — the command printed a `/nix/store/...drv` path. Show it and confirm the module evaluates cleanly.
- **Fail** — non-zero exit or no drv path. Show the **full error output verbatim** (don't truncate or summarize away the Nix error) so the exact broken option/package/line is visible.

## Scripts

- `scripts/de-smoke-check.sh [module-name]` — with no argument, lists the available `lib.deSmoke` module names (Step 1's fallback). With a module name, runs the deep-eval and prints `PASS: <drv>` or `FAIL:` + the full error (Step 2), matching `deep-eval-check.sh`'s convention.

## Key facts

- Working directory: `/home/bosko/NixOS`
- Read-only, safe to run anytime — it only evaluates, never builds or activates.
- `lib.deSmoke` always swaps the target DE into the **laptop** host's other modules (hardware-configuration, environment.nix, networking.nix, nvidia.nix) — a failure could in rare cases stem from a laptop-specific interaction rather than the DE module itself, but for the common case (a typo, an unknown option, a missing package) this is exactly equivalent to what CI's weekly `de-smoke` job runs.
- This is the DE-module-specific counterpart to `deep-eval-check`, which deep-evaluates the four real hosts. Use `deep-eval-check` for hosts, `de-smoke-check` for unwired DE modules.
- If the DE module is actually wired into a host, prefer `nixos-dry-run` / `deep-eval-check` on that host instead — `de-smoke-check` is specifically for the unwired case.
