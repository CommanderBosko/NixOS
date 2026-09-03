---
name: diff-generations
description: Use this skill when the user wants to "diff generations", "what changed after rebuild", "show generation diff", or "what packages changed". Shows what changed between the current NixOS generation and the previous one.
model: haiku
version: 0.2.0
---

# Diff NixOS Generations

Show what changed between the current active NixOS generation and the previous one by comparing store closures.

## Step 1 — Run the diff script

```bash
.claude/skills/diff-generations/scripts/diff-generations.sh
```

The script resolves the previous generation — the highest generation number strictly below the current one that still exists on disk — and runs `nix store diff-closures <previous> /run/current-system`. Read-only and safe. Exit codes:
- `0` — diff printed (parse it in Step 2).
- `2` — no previous generation exists (e.g. the first build); tell the user there's nothing to compare and stop.
- `1` — `/run/current-system` is missing or the current generation number couldn't be resolved; report the error and stop.

## Step 2 — Present the output

Print the **full raw diff first**, then summarise it in three sections (omit any empty section):
- **Added** — a new version with no previous (`foo: ∅ → 1.0`)
- **Removed** — a version dropped to nothing (`foo: 1.0 → ∅`)
- **Updated** — a version change (`foo: 1.0 → 1.1`)

```
Added (N):
  package-name  1.0

Removed (N):
  package-name  1.0

Updated (N):
  package-name  1.0 → 1.1
```

## Step 3 — Note kernel/initrd changes

If any changed package name contains `linux-`, `kernel`, or `initrd`, add:

> Kernel or initrd changed — a reboot is required to activate these changes.

---

## Script

```
.claude/skills/diff-generations/scripts/diff-generations.sh
```

## Key facts

- Working directory: `/home/bosko/NixOS`. Read-only — safe to run any time.
- "Current" generation is `/run/current-system`; the script picks the previous generation automatically (current number − 1, skipping any that were garbage-collected in between). The old "`system-1-link` = previous" shortcut was wrong — that link is literally generation 1.
