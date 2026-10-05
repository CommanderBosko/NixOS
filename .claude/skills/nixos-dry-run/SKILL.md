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

1. Run `/home/bosko/NixOS/.claude/skills/nixos-dry-run/scripts/dry-run.sh` (the full path — a bare `scripts/...` path fails from the Bash tool's cwd).

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
/home/bosko/NixOS/.claude/skills/nixos-dry-run/scripts/dry-run.sh
```

## Gotchas

- **Never run the recommended `nh os switch`/`nh os boot` from this skill.** Both are
  privileged, live-system actions; per this repo's standing rule, hand off any switch/apply
  step to the user rather than attempting it via Bash.

See `references/gotchas.md` for the keyword-heuristic caveat, the TUI-output parsing tip, and the no-host-argument limitation.
