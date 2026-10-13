# fleet-rollout output — <today>

- Mode: ON | OFF
- Result: done | blocked at host <name>, step <n>
- Host order: <order used> (<why, if reordered from the default>)

| Host | Dry-run (Step 4) | Switch (Step 5) + generation | Health sweep (Step 6) |
|------|------------------|------------------------------|-----------------------|
| <host> | clean / error: <msg> | done, gen <N> / handed off, gen <N> / not run | green / failed: <what> / not run |

## Verdict
- done | blocked at host <name>, step <n>: <what failed>
- Rollback recommended: no | yes (`rollback` skill, host <name>)
