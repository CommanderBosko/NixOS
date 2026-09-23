---
name: printer-diagnose
description: Use this skill when the user wants to "diagnose the printer", "printer not showing up", "printer missing in X", "why can't I print", "check cups", or "printer-diagnose". Runs a structured discovery/config/queue check for a network printer on one of this repo's hosts and reports a clear verdict.
model: haiku
version: 0.2.0
---

# Printer Diagnose

Run a read-only diagnostic sweep for "printer not detected / not showing up in print dialog / nothing prints" issues and report which of three layers is broken: mDNS discovery, the CUPS queue (existence + driver), or job delivery. **This skill never modifies system state** — any fix step is handed off to the user.

## Background

- **Since 2026-09-23 the home Canon TS9500 is a static queue, not a cups-browsed one.** `modules/printing.nix` declares `Canon_TS9500_series` via `hardware.printers.ensurePrinters` with a checked-in driverless PPD (`modules/printing/canon-ts9500.ppd`, NickName `Canon Printer, driverless, …`) and `dnssd://` device URI, and sets `services.printing.browsed.enable = false`. `lpadmin` runs in `cups.service`'s postStart, so the queue exists as soon as CUPS is up — no network or boot race involved. There is no `cups-browsed.conf` and no `cups-browsed`/`cups-browsed-fixup` unit any more; their absence is expected, not a fault.
- Why cups-browsed was dropped: its auto-created queue kept vanishing after reboots (it restarted before the printer was resolvable, gave up, never retried), so users "rediscovered" the printer in Print Settings — which auto-picked gutenprint's **"Apollo P-2100"** PPD. Jobs through that driver are silently discarded by the Canon while CUPS logs `Job completed` within seconds, so the queue always looks empty and nothing prints. Any Canon queue whose PPD NickName mentions Gutenprint/Apollo is this bug.
- `.local` resolution can fail briefly after boot (`Unable to connect to <host>.local:631: Temporary failure in name resolution` in the cups journal, seen on natalie-laptop 2026-09-23 while its clock was still reset to 2021 before NTP sync). With the static queue a job just waits and retries instead of failing queue creation.
- A Flatpak app (e.g. Zen Browser) already running before a fix/switch won't see new printer state until relaunched — a stale-session-daemon issue, not a config bug. Check "was the app relaunched" before re-diagnosing a Flatpak/sandbox angle.
- Different apps' print dialogs can legitimately disagree: native/Qt apps (Kate) do live DNS-SD discovery and can show printers with no permanent queue; OnlyOffice's bundled/sandboxed dialog only shows real CUPS destinations. Divergence between them isn't necessarily two separate bugs.

## Arguments

Parse from the user's request:

- **`host`** (optional) — one of `.claude/hosts.json`'s `flakeHosts`. Default: the **local/current box** (no SSH).
- **`printer name`** (optional) — narrows the avahi/lpstat grep (e.g. "Canon", "TS9500"). Default: scan for any IPP entry.

## Steps

### 1. Resolve the host

- If no host is given, or it's the machine you're running on, run the check battery **directly** via Bash.
- If a remote host is named, resolve its SSH target from `/home/bosko/NixOS/.claude/hosts.json` via `bash /home/bosko/NixOS/.claude/lib/resolve-host.sh <name>` (same resolver `ssh-host`/`journal` use), and prefix the script invocation with it.

### 2. Run the check battery

Run `scripts/printer-diagnose.sh [printer-name-pattern]` (relative to this skill's directory), prefixed with the resolved SSH command from Step 1 if remote. It checks, in order: avahi mDNS discovery (5s window), `ippfind`, `lpstat` permanent queues + device URIs, each queue's PPD NickName (the driver), `lpstat -e` discovered-but-unqueued printers, pending/completed jobs, the user's `~/.cups/lpoptions` default, `cups`/`avahi-daemon` state, and this boot's cups journal filtered to job/queue/error lines.

### 3. Interpret and diagnose

The script does no verdict itself — apply this decision tree to its output:

- **No IPP entry in avahi-browse *and* nothing from ippfind** → discovery layer is broken (printer off/asleep, Wi-Fi, firewall — not a NixOS config issue). With the static queue, jobs will sit in `lpstat -o` until the printer is reachable; say so and stop.
- **No `Canon_TS9500_series` in `lpstat -p`** → the declarative queue didn't get created. Check `journalctl -u cups -b` for `lpadmin` errors from postStart, and whether this host has switched to a generation that includes the 2026-09-23 `modules/printing.nix` change (`nixos-rebuild list-generations`) before assuming a repo bug.
- **A Canon queue whose driver line mentions Gutenprint / "Apollo"** (e.g. a `Canon-TS9500-series` re-added via Print Settings) → the silent-discard bug. Propose deleting that queue (Step 4). If it's the system default or the user's `~/.cups/lpoptions` default, that's why "nothing happens".
- **Queue OK, but journal shows `Job completed` seconds after `Queued on` and nothing came out** → job went to the wrong queue/driver (see above) or the printer rejected it; query the printer directly: `ipptool -tv ipp://<printer-ip>/ipp/print get-printer-attributes.test | grep -E 'printer-state|queued-job-count'`.
- **Queue OK, jobs stuck in `lpstat -o`** → delivery failure; the `Unable to connect` / `rror` lines in the journal excerpt name the cause (usually `.local` resolution or the printer being offline).
- **Everything OK** → if the user's app still doesn't see it, suspect the stale-Flatpak-session pattern above.

### 4. Propose the fix (never run it directly)

Only `vpn-server` has passwordless sudo — every other host needs an interactive password the Bash tool can't supply, so hand privileged steps to the user via the `!` prefix rather than attempting them directly (even over SSH).

- Bogus/duplicate queue: `sudo lpadmin -x <queue-name>` (e.g. `Canon-TS9500-series`). The declarative `Canon_TS9500_series` is re-asserted on every CUPS start, so never delete that one as a "fix".
- Stale per-user default pointing at a deleted queue: `lpoptions -d Canon_TS9500_series` (as that user, no sudo).
- Stuck job: `cancel -a Canon_TS9500_series` or `sudo systemctl restart cups` (re-runs the ensurePrinters postStart too).

After the user confirms, re-run `lpstat -p -d -v` (same host-prefixed pattern) to confirm.

### 5. Report

Output a compact three-line verdict plus the specific next action, e.g.:

```
Discovery  ✅ Canon TS9500 visible via avahi + ippfind
Queue      ❌ default is Canon-TS9500-series (Gutenprint "Apollo P-2100" driver)
Jobs       ❌ job 6 "completed" in 6s, nothing printed (silent discard)
Next step: run `sudo lpadmin -x Canon-TS9500-series` on gaming, then re-check lpstat -p -d
```

## Notes

- Read-only and safe — no confirmation needed to run the check battery itself; only the proposed privileged fixes need the user's own hands.
- This is a **project-local** skill: it lives under the repo's `.claude/skills/` and is picked up directly. No Home Manager symlink or rebuild is required.
- `scripts/printer-diagnose.sh` holds the mechanical check battery; this file keeps the interpretation, which needs context (which host, recent switch history, Flatpak relaunch state) the script can't have on its own.

## Scripts

- `scripts/printer-diagnose.sh [printer-name-pattern]` — runs the discovery/queue/driver/job/journal check battery (Step 2). Runs locally; the skill prefixes the whole invocation with the resolved SSH command for a remote host.
