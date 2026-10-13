# flake-update-verify run — <today>

## Inputs changed

| Input | Old rev | New rev | New date |
|---|---|---|---|
| <input> | <old rev> | <new rev> | <YYYY-MM-DD> |

Unchanged: <inputs, or "none">. (On "Nothing to do", replace the table with "none".)

## Eval verdict

- `nix flake check` (`flake-check`): <passed | failed + the error>
- `deep-eval-check`: <N passed, M failed (of N+M)> — one PASS/FAIL line per host

## Final state

<exactly one of:>
- **Committed** `<sha>` (`chore(flake): bump inputs <today>`), flake.lock only, pushed to
  <remote>/<branch>. No switch/boot run.
- **Nothing to do** — `nix flake update` produced no `flake.lock` change.
- **Reverted** — `flake.lock` restored to its previous state. Offending input: <input>
  (<what broke>). Apply later via `/fleet-rollout` once it's healthy.
