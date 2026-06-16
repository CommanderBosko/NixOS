---
name: verify-service
description: After adding or activating a NixOS service, run a structured health sweep for one named service on a host. Use when the user says "verify service X", "check that X came up", "is jellyfin running", "health-check X on gaming", or "verify X after rebuild".
---

# Verify Service

Run a read-only health sweep for a single systemd service on one of this repo's hosts and report a clear PASS/FAIL per check. Use it right after a rebuild/activation to confirm a service actually came up (or was intentionally removed). **This skill never modifies system state.**

## Arguments

Parse from the user's request:

- **`<unit>`** (required) — the systemd unit / service name, e.g. `jellyfin`, `qbittorrent`, `wg-quick-wg0`.
- **`host`** (optional) — one of `gaming`, `laptop`, `natalie-laptop`, `vpn-server`. Default: the **local/current box** (no SSH).
- **mount path** (optional) — a backing mount to check, e.g. `/mnt/media`.
- **data dir** (optional) — a data/library/download dir to check ownership on, e.g. `/mnt/media/downloads`.
- **absent mode** (optional) — if the user is confirming a service was *intentionally removed* (e.g. "confirm qbittorrent service is gone"), invert the service check so "not found / inactive" is a PASS.

## Steps

### 1. Resolve the host

- If no host is given, or the host is the machine you're running on, run all commands **directly** via Bash.
- If a remote host is named, prefix each command with the repo's `ssh-host` convention (resolve the short host name to the correct `ssh` command — invoke / mirror the `ssh-host` skill). `vpn-server` is reachable over the WireGuard VPN.
- Run the checks below in a **single combined command** where possible to keep it to one round-trip.

### 2. Service check (always)

```bash
systemctl is-active <unit>
systemctl status <unit> --no-pager -n 5
```

- **Normal mode:** `active` → PASS. `inactive`/`failed`/`Unit ... could not be found` → FAIL (show the status tail).
- **Absent mode:** `Unit ... could not be found` (or inactive) → PASS; still running → FAIL.

### 3. Port check (always, when the service listens)

Detect what the unit is listening on:

```bash
ss -tlnp 2>/dev/null | grep -E '<unit>|<known-port>'
ss -ulnp 2>/dev/null | grep -E '<unit>|<known-port>'   # only if UDP is relevant (e.g. DLNA 1900/7359)
```

- Report the listening ports. A service binding `0.0.0.0` is **fine** when the firewall scopes access per-interface — e.g. Jellyfin binds `0.0.0.0:8096` but is only reachable on `enp4s0` (LAN) + `wg0` (WireGuard). Note this rather than flagging it.
- Some services have **no listening socket by design** (e.g. the qBittorrent *GUI app* has no Web UI daemon). If so, say "no listening port expected" — not a FAIL.

### 4. Mount check (only if a mount path was given)

```bash
findmnt <path>
```

- Mounted → PASS; report source device, fstype, and `rw`/`ro`. Not mounted → FAIL.
- Example: `/mnt/media` should be `/dev/sda1 ext4 rw`.

### 5. Data-dir check (only if a dir was given)

```bash
ls -ld <dir> <dir>/* 2>&1
```

- Report `owner:group` and mode. Flag anything that looks wrong for the service to read/write.
- Reference layout from this repo: `/mnt/media`, `/mnt/media/Movies`, `/mnt/media/Shows`, `/mnt/media/downloads` are all expected to be `bosko:media`, mode `2775` (setgid) so the `jellyfin` user (in the `media` group) can read manually-dropped files.

### 6. Summarize

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
