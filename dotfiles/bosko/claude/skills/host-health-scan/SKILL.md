---
name: host-health-scan
description: Run a read-only full health scan of the current host and give a green/watch/actionable verdict — failed units, disk/RAM, NVMe SMART, battery wear, temps, and the noise-filtered boot journal. Use when the user says "health scan", "health check this host", "full health scan", "scan this machine", or "is this host healthy".
---

# Host Health Scan

One-shot, read-only health scan of whichever host you're on, ending in a verdict. Reports in chat only — it writes no memory (offer to `save-memory` if the user wants the result kept). (Bucket: Verification)

For a quick all-hosts table (generation, failed units, staged, reboot-pending) use `fleet-status` instead; this skill is the deep single-host scan.

## Steps

### 1. Collect

Run the scan script — a fixed sequence of read-only commands:

```bash
/home/bosko/.claude/skills/host-health-scan/scripts/health-scan.sh
```

(Use the absolute path — see `~/.claude/skills/lib/script-paths.md`. Before the first rebuild after this skill was added, run it from the repo copy: `dotfiles/bosko/claude/skills/host-health-scan/scripts/health-scan.sh`.)

### 2. Interpret

Sort every finding into green / watch / actionable:

- **Failed units** — any entry is actionable; point at the `journal` skill for that unit.
- **Disk / RAM / load** — watch if `/` or `/boot` >80%, or sustained PSI/load; otherwise green.
- **NVMe SMART** — actionable if overall health isn't PASSED, Critical Warning ≠ 0, Available Spare near its threshold, or Media/Data Integrity Errors > 0. Watch on Percentage Used rising fast. **Unsafe Shutdowns**: the laptop baseline is 102, static across a clean reboot — watch only if it climbs after clean reboots. If SMART output is missing (`sudo -n` denied), say so; don't call it green. `--scan` lists `/dev/nvme0`, not `nvme0n1`.
- **Battery** — wear = `energy-full` / `energy-full-design`; low wear is normal, not a fault. Confirm `charge_control_end_threshold` matches the configured cap (80 on laptop). Skipped on desktops.
- **Temps** — watch only if package/NVMe is near its critical limit. Fan RPM 0 / N/A on the ASUS laptop is the ACPI firmware bug, not a dead fan.
- **Boot journal** — the script already drops known-benign noise (ACPI CFSP/TFN1, dbus-broker duplicates, cupsd/colord, io pressure threshold, VMD bus, early-boot `/srv/shared` CIFS) and prints counts of what it dropped. Anything left is a candidate.

### 3. Report

Give a short verdict: **green** (nothing to do), **watch** (list items and what would change it), or **actionable** (list fixes). Keep a one-line "key numbers" summary (disk %, RAM, NVMe used/spare, battery wear, temps).

### 4. Escalate unknown errors

If the journal section shows an unknown, non-benign error, ask via **AskUserQuestion** whether to hand off to `boot-error-triage` for root-causing (Recommended) or leave it. If an error turns out to be benign, add its pattern to `NOISE_PATTERNS` in `boot-error-triage/scripts/collect-boot-diagnostics.sh` rather than filtering by hand.

## Scripts

- `scripts/health-scan.sh` — no arguments; read-only scan of the current host (uses `sudo -n smartctl` only). Called by step 1. Reuses `boot-error-triage`'s collector for the journal section.
