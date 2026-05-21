---
name: flake-check
description: Use this skill when the user wants to "check flake", "validate flake", "nix flake check", or "check for errors". Validates the flake before committing or rebuilding and surfaces any evaluation errors clearly.
version: 0.1.0
---

# Flake Check

Validate the NixOS flake for evaluation errors before committing or rebuilding. This is a read-only operation that catches syntax errors, undefined variables, and broken derivations without touching the running system.

## Step 1 — Run the check

```bash
nix flake check /home/bosko/NixOS 2>&1
```

Capture stdout and stderr together. The check can take a while if it needs to evaluate all host configurations — allow up to 5 minutes (300000ms timeout).

## Step 2 — Report the result

### On success (exit 0)

```
Flake check passed — no evaluation errors found.
```

Also note if any warnings were printed even on success (e.g. deprecation notices) — show them so the user can decide whether to address them.

### On failure (non-zero exit)

Show the **full error output** verbatim — Nix error messages contain the exact file and line number needed to fix the problem. Do not truncate.

Then add a brief diagnosis below the raw output:

- **Syntax error** — `error: syntax error` — point to the file and line
- **Undefined variable** — `error: undefined variable` — name the variable and the file
- **Infinite recursion** — `error: infinite recursion` — often caused by a circular `mkMerge` or self-referential option
- **Hash mismatch / missing source** — may need `nix flake update` or a network fetch
- **Unknown option** — option path doesn't exist in nixpkgs; check spelling against nixpkgs source

## Step 3 — Suggest next steps

- If the check **passed**: safe to proceed with `nh os boot /home/bosko/NixOS --dry` or commit.
- If the check **failed**: fix the reported error, then re-run `flake-check` before rebuilding.

---

## Key facts

- Working directory: `/home/bosko/NixOS`
- This is a read-only, safe-to-run-anytime operation.
- `nix flake check` evaluates all `nixosConfigurations` outputs — this catches errors across all five hosts (gaming, laptop, server, natalie-laptop, vpn-server).
- This skill does NOT apply changes; it only validates.
