---
name: deep-eval-check
description: Use this skill when the user wants to "deep-eval check", "really check the flake", "does it actually build", "check all hosts deep-eval", or "prove the config builds". Forces a real per-host build-graph evaluation across all four NixOS hosts, catching failures that `nix flake check` misses.
model: haiku
version: 0.1.0
---

# Deep Eval Check

Force Nix to fully evaluate each host's build graph — not just confirm it's a derivation — so a package deep in `environment.systemPackages` that's broken (e.g. newly marked insecure, a hash mismatch, an unbuildable dependency) surfaces before a real rebuild does. (Bucket: Verification)

## Why this exists

`nix flake check` only verifies each host's toplevel attribute resolves to a derivation — it does not force full evaluation. A host can pass `flake-check` and still fail every real `nh os boot`. This happened 2026-07-02 with a pnpm/vesktop insecure-package regression (see `flake-check`'s own Gotchas section and memory `project_pnpm_insecure_waiver.md`). This skill closes that gap.

## Step 1 — Deep-evaluate each host

Run `.claude/skills/deep-eval-check/scripts/deep-eval-check.sh` (repo-root-relative — a bare `scripts/...` path 404s from the actual Bash-tool cwd). It reads the host list
live from `.flakeHosts` in `/home/bosko/NixOS/.claude/hosts.json` (never hardcode the host
list — that's the single source of truth other skills like `fleet-rollout` already read from)
and deep-evaluates each host's `config.system.build.toplevel.drvPath` in turn, printing
`PASS: <drv>` or `FAIL:` + the full error per host. This forces full evaluation of the build
graph, which can take a while — allow up to 5 minutes (300000ms timeout) total for all hosts,
longer on the first run after a nixpkgs bump before the eval cache is warm.

## Step 2 — Report per-host result

For each host, report:
- **Pass** — the command printed a `/nix/store/...drv` path. Show it.
- **Fail** — non-zero exit or no drv path printed. Show the **full error output verbatim** (don't truncate or summarize away the Nix error) so the exact broken package/file/line is visible.

## Step 3 — Summarize

End with a one-line summary table of green vs. red hosts, e.g.:

```
gaming: PASS
laptop: PASS
natalie-laptop: FAIL — see error above
vpn-server: PASS
```

If everything passed:
```
All 4 hosts deep-eval clean — safe to proceed with a real rebuild or fleet-rollout.
```

If anything failed, do not suggest rebuilding that host until the reported error is fixed.

## When to run this

- Right after `nix flake update` / a nixpkgs bump — new package versions are the most common source of deep-eval-only failures.
- As a pre-step before `/fleet-rollout`, since a shallow `flake-check` pass is not sufficient guarantee.
- `flake-check` alone is NOT enough for these cases — it's a faster, shallower first pass; this skill is the real gate.

## Key facts

- Working directory: `/home/bosko/NixOS`
- Read-only, safe to run anytime — it only evaluates, never builds or activates.
- Slower than `flake-check` (forces full evaluation per host) — expect it to take noticeably longer, especially the first run after a nixpkgs bump before the eval cache is warm.
- `.claude/skills/deep-eval-check/scripts/deep-eval-check.sh` requires `jq` (already used by other host-touching skills via `hosts.json`) and exits non-zero if any host fails, without stopping early — every host is still evaluated and reported.
