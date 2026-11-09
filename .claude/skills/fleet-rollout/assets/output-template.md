# fleet-rollout output — <today>

- Mode: ON | OFF
- Activation: boot | switch
- Result: done | blocked at host <name>, step <n>
- Host order: <order used> (<why, if reordered from the default — boot mode always puts the local host last>)

| Host | Dry-run / build gate (Step 4) | Stage or switch (Step 5) + generation | Reboot (Step 5b) | Health sweep (Step 6) |
|------|-------------------------------|----------------------------------------|------------------|-----------------------|
| <host> | clean / error: <msg> | done, gen <N> / handed off, gen <N> / not run | rebooted / n/a (local or switch mode) | green / failed: <what> / not run |

## Verdict
- done | blocked at host <name>, step <n>: <what failed>
- Pending reboot: none | <local host> (boot mode: staged gen <N>, reboot it, then run `/fleet-status`)
- Rollback recommended: no | yes (`rollback` skill, host <name>)
