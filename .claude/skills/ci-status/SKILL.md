---
name: ci-status
description: Check or watch the latest GitHub Actions "flake check" run for this repo and report the verdict. Use when the user says "ci status", "is CI green", "check CI", "watch the run", "did the workflow pass", or "check the actions run".
---

# CI Status

Report the verdict of the most recent GitHub Actions `flake check` run for `CommanderBosko/NixOS` — watching it to completion if it is still in progress. (Bucket: Verification)

## Steps

1. **Find the latest run:**

   ```bash
   gh run list --repo CommanderBosko/NixOS --workflow "flake check" --limit 3
   ```

   The first line is the latest run; note its run ID, status, branch, and triggering commit subject. If the user named a specific commit or branch, pick the matching run instead of the first.

2. **If the run is `in_progress` or `queued`, watch it to completion:**

   ```bash
   gh run watch <run-id> --repo CommanderBosko/NixOS --exit-status --interval 20
   ```

   Allow up to 10 minutes (timeout 600000ms) — the deep-eval job normally finishes in ~2–3 minutes. If the run is already `completed`, skip the watch.

3. **On success:** report the verdict in one or two sentences — run conclusion, duration, which commit it certified. Green means every host's full system derivation evaluated (`flake check` + the per-host deep-eval step), not that anything was built or deployed.

4. **On failure:** pull the failing step's log and show the relevant error verbatim:

   ```bash
   gh run view <run-id> --repo CommanderBosko/NixOS --log-failed | tail -40
   ```

   Identify which host failed to evaluate (the deep-eval step groups output per host with `::group::<host>`) and, if the error names a package or option, say which one. Suggest the next move — usually reproducing locally with `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`.

5. **Edge cases:**
   - No runs listed → the workflow has never fired since its introduction (2026-07-02); say so.
   - Run `cancelled` → usually superseded by a newer push (the workflow's concurrency group cancels in-flight runs); check for a newer run and report that one instead.

## Arguments

Optional, from the user's phrasing: a **branch**, **commit SHA/subject**, or **run ID** to check instead of the latest run (e.g. "check CI for 3015529"). With no argument, use the newest `flake check` run.
