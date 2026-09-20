# Shared Module Check — Incidents

Background incidents motivating why this skill exists and why Step 2 uses
`classify-shared-file.sh` instead of a plain array-membership check.

## Why this skill exists

`commonModules` and `desktopModules` in `flake.nix` compose every host from the same shared
files. Editing one of them (or `flake.nix` itself) can break a host you never touched
directly and never ran a local check against. This isn't hypothetical: `deep-eval-check`'s
own history includes a 2026-07-02 pnpm/vesktop insecure-package regression that a shallow
`flake-check` missed, and on 2026-07-18 an `rtk` package reference added to
`modules/users.nix` broke `vpn-server`'s evaluation entirely (it pins `nixpkgs-25.11` stable
on `aarch64-linux`, where the package didn't exist yet) — uncaught because the commit that
introduced it only exercised the local (unstable, x86_64) host. This skill closes that gap
by making the cross-host sweep the default next step after any shared-file edit, not an
optional afterthought.

## Array-membership check missed direct multi-host wiring

**A plain membership check against the two named arrays (`commonModules`/`desktopModules`)
misses a module wired directly into 2+ hosts' own per-host module lists.** Found 2026-09-04
via `skill-audit`: `modules/desktop-environments/niri.nix` is imported directly by
`gaming`'s and `natalie-laptop`'s host blocks (and via `laptopModules` for `laptop`) — three
hosts — without ever appearing in `desktopModules`, so the old Step 2 test silently skipped
the 4-host sweep for the one DE module actually in production use. Fixed by routing Step 2
through `classify-shared-file.sh`, which also checks for direct multi-host references, not
just array membership.
