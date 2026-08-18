---
name: ci-status
description: Check or watch the latest GitHub Actions "flake check" run for this repo and report the verdict. Use when the user says "ci status", "is CI green", "check CI", "watch the run", "did the workflow pass", or "check the actions run".
model: haiku
---

# CI Status

Report the verdict of the most recent GitHub Actions `flake check` run for `CommanderBosko/NixOS` — watching it to completion if it is still in progress. (Bucket: Verification)

## Steps

1. **Resolve, watch, and report** by running the script (repo-root-relative — a bare `scripts/...` path 404s from the actual Bash-tool cwd), passing the user's filter if they gave one:

   ```bash
   .claude/skills/ci-status/scripts/ci-status.sh [branch|commit-sha|run-id|title-substring]
   ```

   It finds the matching run (newest `flake check` run if no filter), watches it to completion if `in_progress`/`queued` (allow up to 10 minutes — timeout 600000ms; the deep-eval job normally finishes in ~2–3 minutes), prints the run id/branch/title/status, and on failure prints the last 40 lines of the failing step's log. Exit code mirrors the run's own success/failure. If no run matches the filter, it prints the 10 most recent runs instead so you can pick by eye.

2. **On success:** report the verdict in one or two sentences — run conclusion, which commit it certified. Green means every host's full system derivation evaluated (`flake check` + the per-host deep-eval step), not that anything was built or deployed.

3. **On failure:** the script already printed the failing step's log tail — interpret it. Identify which host failed to evaluate (the deep-eval step groups output per host with `::group::<host>`) and, if the error names a package or option, say which one. Suggest the next move — usually reproducing locally with `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`.

4. **Edge cases:**
   - No runs listed → the workflow has never fired since its introduction (2026-07-02); say so.
   - Run `cancelled` → usually superseded by a newer push (the workflow's concurrency group cancels in-flight runs); check for a newer run and report that one instead.

## Scripts

- `.claude/skills/ci-status/scripts/ci-status.sh [filter]` — resolves the target run (branch, commit SHA, run ID, or title substring; newest run if omitted), watches it to completion if still running, and on failure prints the failed step's log tail. Read-only.

## Arguments

Optional, from the user's phrasing: a **branch**, **commit SHA/subject**, or **run ID** to check instead of the latest run (e.g. "check CI for 3015529"). With no argument, use the newest `flake check` run.
