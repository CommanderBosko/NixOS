---
name: nixos-dry-run
description: This skill should be used when the user wants to "dry run", "preview rebuild", "see what would change", "check config", "test build", or "see changes before applying". Use it to preview what nh os boot would change without writing anything to the system.
model: haiku
version: 0.2.0
---

# NixOS Dry-Run Preview

Run a dry-run build of the NixOS configuration to preview what would change without applying anything to the system. This is a safe, read-only operation.

(Bucket: Verification — this is the pre-rebuild gate that proves the config still evaluates and shows the change set before anything is applied. It does one job: build-and-report, no writes. File it alongside `/flake-check` and `/verify-service`, not as a general utility.)

## Arguments

None — this skill takes no user-supplied arguments.

## Instructions

1. Run `scripts/dry-run.sh` from the skill's directory (or use the full path).

2. The script runs `nh os boot /home/bosko/NixOS --dry`. Parse its output and summarise:
   - Which packages would be added, removed, or updated (look for lines with `+`, `-`, or version changes)
   - Which systemd services would be started, stopped, or restarted
   - Whether any kernel or initrd changes are present (these require a reboot to take effect regardless)
   - The total closure size delta if reported

3. Present the summary in plain language. If the output is long, show the full diff first, then summarise below it.

4. If the build fails (non-zero exit), show the full error output so the user can diagnose it. Common failures:
   - Nix evaluation errors (syntax or undefined variable) — show the exact line
   - Hash mismatches (network fetch needed) — note the user may need `nix flake update`

5. This skill is safe to invoke without confirmation — it does not modify any system state.

6. After the diff, the script also prints a `RECOMMENDATION:` line — either `switch` or `boot` —
   based on keyword heuristics over the diff (kernel/initrd/bootloader/firmware → always `boot`;
   display-manager/graphics-driver/compositor → `boot` to avoid crashing the live session;
   otherwise → `switch`, since it's safe to apply immediately with no reboot needed). Surface
   this recommendation and its reason to the user in your summary. **Do not run `nh os switch`
   or `nh os boot` yourself** — this skill stays read-only; hand the actual apply step to the
   user to run themselves (see sudo-gated steps note below).

## Script

```
scripts/dry-run.sh
```

## Gotchas

- **The switch/boot recommendation is a keyword heuristic, not exhaustive.** It scans the raw
  diff text for package-name substrings (`nvidia`, `sddm`, `niri`, `linux-`, etc.), so it can
  miss changes that don't show up under those names (e.g. a security-critical config change
  wrapped in a differently-named derivation) or a low-risk service that happens to have a
  session-risk keyword in an unrelated path. Treat it as a strong default suggestion, not an
  infallible verdict — still show the user the underlying diff.
- **Never run the recommended `nh os switch`/`nh os boot` from this skill.** Both are
  privileged, live-system actions; per this repo's standing rule, hand off any switch/apply
  step to the user rather than attempting it via Bash.

- **`nh os boot --dry`'s output is a redrawing TUI tree**, not a flat log — most of it is
  self-overwriting progress-bar escape sequences, and the actually useful summary (the
  `<<<`/`>>>` store-path diff plus `PATHS:`/`SIZE:`/`DIFF:` lines) sits at the very end.
  Piping through a large `tail -N` (e.g. `tail -60`) still surfaces a wall of tree/progress
  noise. Prefer `tail -8` (the summary is always the last handful of lines) or
  `grep -E '^(PATHS|SIZE|DIFF):'` to jump straight to the change summary.
- **Only checks the local host — takes no host argument.** `nh os boot --dry` always builds
  *this machine's* config, even if you pass a different host name; the skill has no argument
  handling, so it's silently ignored rather than erroring. To verify a host you're not on
  (e.g. `natalie-laptop`, `vpn-server`), use `deep-eval-check` (all 4 hosts) or
  `shared-module-check` (impact of a shared-file edit) instead — this tripped us up
  2026-07-18 trying to dry-run `natalie-laptop` from `gaming`.
