# Fleet Rollout — Step 5 hand-offs and the vpn-server deploy

Load this when Step 5 is about to hand a switch to the user, or before working around
either rule below (running a desktop switch directly, or `switch`-ing vpn-server over SSH).

## Why Step 5 hands off every desktop host (no NOPASSWD sudo)

No NOPASSWD sudo rule exists on the local host or on any other desktop host (`desktop: true`
in `.claude/hosts.json`), so Claude cannot supply a sudo password — `nh os switch` /
`nixos-rebuild switch --target-host` will just fail with "a terminal is required to read the
password" if attempted directly via the Bash tool (same failure mode documented in the
`rollback` and `nixos-gc` skills). The same missing-NOPASSWD problem applies over SSH to a
remote desktop host.

So Step 5 always stops and hands the switch command to the user, **regardless of Training
Mode**, the same way the mandatory commit gate in `flake-update-verify` can't be skipped by
OFF mode. Budget for that pause even on unattended/`/loop`-scheduled runs. Don't "fix" that
by trying to run them directly, and don't treat a hand-off as the step being blocked; it's
the expected path.

Only `vpn-server` has passwordless sudo (`"sudo": "passwordless"` in hosts.json), so it is
the one host Claude can deploy itself — via `remote-rebuild`, below.

## Why vpn-server never uses `switch` over SSH

`vpn-server` is the one host with passwordless sudo, but still can't use `switch` over SSH.
`switch-to-configuration` restarts networking, which drops the SSH session mid-activation
and leaves firewall/NAT state inconsistent (symptom: `MASQUERADE` present but
FORWARD/conntrack at zero). Always deploy vpn-server via the `remote-rebuild` skill's
`boot` + reboot method (root cause in that skill's Gotchas), never
`nixos-rebuild switch --target-host vpn-server` directly.
