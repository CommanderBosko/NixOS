# printer-diagnose: incident-specific Step 3 branches

Apply these alongside the three-layer decision tree in SKILL.md Step 3. Both are the Gutenprint "Apollo" silent-discard bug described in `background.md`.

- **A Canon queue whose driver line mentions Gutenprint / "Apollo"** (e.g. a `Canon-TS9500-series` re-added via Print Settings) → the silent-discard bug. Propose deleting that queue (SKILL.md Step 4). If it's the system default or the user's `~/.cups/lpoptions` default, that's why "nothing happens".
- **Queue OK, but journal shows `Job completed` seconds after `Queued on` and nothing came out** → job went to the wrong queue/driver (see above) or the printer rejected it; query the printer directly: `ipptool -tv ipp://<printer-ip>/ipp/print get-printer-attributes.test | grep -E 'printer-state|queued-job-count'`.
