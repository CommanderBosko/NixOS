---
name: verify-service
description: After adding or activating a NixOS service, run a structured health sweep for one named service on a host. Use when the user says "verify service X", "check that X came up", "is jellyfin running", "health-check X on gaming", or "verify X after rebuild".
---

# Verify Service

Run a read-only health sweep for a single systemd service on one of this repo's hosts and report a clear PASS/FAIL per check. Use it right after a rebuild/activation to confirm a service actually came up (or was intentionally removed). **This skill never modifies system state.**

## Arguments

Parse from the user's request:

- **`<unit>`** (required) — the systemd unit / service name, e.g. `jellyfin`, `qbittorrent`, `wg-quick-wg0`.
- **`host`** (optional) — one of `.claude/hosts.json`'s `flakeHosts` (enumerate live, don't hardcode: `jq -r '.flakeHosts[]' /home/bosko/NixOS/.claude/hosts.json`). Default: the **local/current box** (no SSH).
- **mount path** (optional) — a backing mount to check, e.g. `/mnt/media`.
- **data dir** (optional) — a data/library/download dir to check ownership on, e.g. `/mnt/media/downloads`.
- **absent mode** (optional) — if the user is confirming a service was *intentionally removed* (e.g. "confirm qbittorrent service is gone"), invert the service check so "not found / inactive" is a PASS.

## Steps

### 1. Resolve the host

- If no host is given, or the host is the machine you're running on, run all commands **directly** via Bash.
- If a remote host is named, resolve its SSH target from the single source of truth, `/home/bosko/NixOS/.claude/hosts.json` (`jq -r '.hosts["<host>"].ssh' …` — the same data the `ssh-host` skill reads), and prefix each command with it. `vpn-server` is reachable over the WireGuard VPN.
- Run the checks below in a **single combined command** where possible to keep it to one round-trip.

### 2. Run the check battery

Run `scripts/verify-service.sh <unit> [mount-path] [data-dir] [port-pattern]` (relative to
this skill's directory) — prefixed with the resolved SSH command from Step 1 if remote. It
runs, in order: the service check (always), the tcp+udp port check (always), the mount check
(only if a mount path was given), and the data-dir check (only if a dir was given).
`port-pattern` defaults to the unit name; pass a known port too (e.g. `8096`) if the process
name doesn't appear verbatim in `ss` output.

Interpret the raw output — the script does no PASS/FAIL judgment itself, that stays here:

- **Service — Normal mode:** `active` → PASS. `inactive`/`failed`/`Unit ... could not be found` → FAIL (show the status tail). **Absent mode:** `Unit ... could not be found` (or inactive) → PASS; still running → FAIL.
- **Ports:** report the listening ports found. A service binding `0.0.0.0` is **fine** when the firewall scopes access per-interface — e.g. Jellyfin binds `0.0.0.0:8096` but is only reachable on `enp4s0` (LAN) + `wg0` (WireGuard). Note this rather than flagging it. Some services have **no listening socket by design** (e.g. the qBittorrent *GUI app* has no Web UI daemon) — if so, say "no listening port expected", not a FAIL. Also note: `ss -tlnp`'s process-name column requires root to populate — a "no match" without root doesn't necessarily mean nothing is listening; check the raw `ss` output for the port number too before calling it a FAIL.
- **Mount:** mounted → PASS; report source device, fstype, and `rw`/`ro`. Not mounted → FAIL. Example: `/mnt/media` should be `/dev/sda1 ext4 rw`.
- **Data dir:** report `owner:group` and mode. Flag anything that looks wrong for the service to read/write. Reference layout from this repo: `/mnt/media`, `/mnt/media/Movies`, `/mnt/media/Shows`, `/mnt/media/downloads` are all expected to be `bosko:media`, mode `2775` (setgid) so the `jellyfin` user (in the `media` group) can read manually-dropped files.

### 3. Summarize

Output a compact checklist — one line per check with PASS/FAIL and a one-line reason — then an overall verdict:

```
✅ Service   jellyfin — active (running)
✅ Port      8096/tcp listening (0.0.0.0; firewall-scoped to enp4s0+wg0)
✅ Mount     /mnt/media ← /dev/sda1 ext4 rw
✅ Folders   Movies/ Shows/ — bosko:media 2775
Verdict: all checks passed.
```

If anything FAILED, suggest the next step (e.g. `journal` skill for the unit's logs, or re-check the mount with `lsblk`).

## Notes

- Read-only and safe — no confirmation needed to run.
- This is a **project-local** skill: it lives under the repo's `.claude/skills/` and is picked up directly. No `bosko-claude.nix` symlink or rebuild is required (that only applies to the global, repo-managed skills under `dotfiles/bosko/claude/skills/`).
- `scripts/verify-service.sh` holds the mechanical check battery; this file keeps only the PASS/FAIL interpretation, which needs context the script can't have (firewall scoping, expected-absent daemons, root-vs-non-root `ss` output).
