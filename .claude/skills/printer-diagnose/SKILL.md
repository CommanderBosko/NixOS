---
name: printer-diagnose
description: Use this skill when the user wants to "diagnose the printer", "printer not showing up", "printer missing in X", "why can't I print", "check cups", or "printer-diagnose". Runs a structured discovery/config/queue check for a network printer on one of this repo's hosts and reports a clear verdict.
model: haiku
version: 0.1.0
---

# Printer Diagnose

Run a read-only diagnostic sweep for "printer not detected / not showing up in print dialog" issues and report which of three layers is broken: mDNS discovery, cups-browsed config, or the actual CUPS queue. **This skill never modifies system state** — any fix step is handed off to the user.

## Background

- `modules/printing.nix` sets `services.printing.browsedConf = "CreateIPPPrinterQueues Everywhere"` (commit `6877f4b`). This overrides cups-browsed's compiled-in `CreateIPPPrinterQueues=LocalOnly` default, which never auto-creates a CUPS queue for a real network IPP printer — only for IPP-over-USB. Symptom without this: `avahi-browse`/`lpstat -e` show the printer fine (discovery works), but `lpstat -p` shows no destination (no queue), so print dialogs are empty.
- Even with that config correct, `cups-browsed.service` has `BindsTo=avahi-daemon.service`/`PartOf=avahi-daemon.service` — every avahi-daemon restart resets it, and it needs one uninterrupted run afterward to actually instantiate the permanent queue. This is a known, **not yet permanently fixed** recurrence risk (seen repeatedly on natalie-laptop, tied to past network/VPN churn restarting avahi-daemon).
- A Flatpak app (e.g. Zen Browser) already running before a fix/switch won't see new printer state until relaunched — a stale-session-daemon issue, not a config bug. Check "was the app relaunched" before re-diagnosing a Flatpak/sandbox angle.
- Different apps' print dialogs can legitimately disagree: native/Qt apps (Kate) do live DNS-SD discovery and can show a printer before any permanent queue exists; OnlyOffice's bundled/sandboxed dialog only shows real, already-created CUPS destinations. Divergence between them isn't necessarily two separate bugs.

## Arguments

Parse from the user's request:

- **`host`** (optional) — one of `.claude/hosts.json`'s `flakeHosts`. Default: the **local/current box** (no SSH).
- **`printer name`** (optional) — narrows the avahi/lpstat grep (e.g. "Canon", "TS9500"). Default: scan for any IPP entry.

## Steps

### 1. Resolve the host

- If no host is given, or it's the machine you're running on, run the check battery **directly** via Bash.
- If a remote host is named, resolve its SSH target from `/home/bosko/NixOS/.claude/hosts.json` via `bash /home/bosko/NixOS/.claude/lib/resolve-host.sh <name>` (same resolver `ssh-host`/`journal` use), and prefix the script invocation with it.

### 2. Run the check battery

Run `scripts/printer-diagnose.sh [printer-name-pattern]` (relative to this skill's directory), prefixed with the resolved SSH command from Step 1 if remote. It checks, in order: avahi mDNS discovery, `/etc/cups/cups-browsed.conf` contents, `lpstat` permanent queues, `lpstat -e` discovered-but-unqueued printers, live service state, and the last 100 combined `cups-browsed`/`avahi-daemon` journal lines.

### 3. Interpret and diagnose

The script does no verdict itself — apply this decision tree to its output:

- **No IPP entry in avahi-browse** → discovery layer is broken (network/firewall/printer itself, not a NixOS config issue). Stop here; this is out of scope for a config fix.
- **avahi OK, but `cups-browsed.conf` missing `CreateIPPPrinterQueues Everywhere` (or the file is empty)** → config not active. Check whether the current generation actually includes `modules/printing.nix`'s fix (`nixos-rebuild list-generations` / when this host last switched) before assuming it needs a repo change — the fix may just not be switched/activated yet on this host.
- **avahi OK, config OK, `lpstat -p -d` shows a destination** → working as expected; if the user's app still doesn't see it, suspect the stale-Flatpak-session pattern above (ask if the app was relaunched since the last switch/restart).
- **avahi OK, config OK, but `lpstat -p -d` shows no destination** → the BindsTo race. Check the journal excerpt for recent `avahi-daemon` restarts around when `cups-browsed` also cycled. If found, this is the known recurrence — propose the fix in Step 4. If no avahi restart is visible in the last 100 lines, widen the journal window (`journalctl -u cups-browsed -u avahi-daemon --no-pager --since "-6 hours"` via the same host prefix) before concluding it's something else.

### 4. Propose the fix (never run it directly)

If the BindsTo race is the diagnosis, tell the user to run, on that host:

```
sudo systemctl restart cups-browsed
```

Only `vpn-server` has passwordless sudo — every other host needs an interactive password the Bash tool can't supply, so hand this off via the `!` prefix rather than attempting it directly (even over SSH). After the user confirms it ran, re-check with `lpstat -p -d` (same host-prefixed pattern) roughly 30 seconds later to confirm the queue materialized.

### 5. Report

Output a compact three-line verdict plus the specific next action, e.g.:

```
Discovery  ✅ Canon_TS9500 visible via avahi
Config     ✅ CreateIPPPrinterQueues Everywhere set
Queue      ❌ no destination — avahi-daemon restarted 3m ago (BindsTo race)
Next step: run `sudo systemctl restart cups-browsed` on natalie-laptop, then re-check lpstat -p -d
```

## Notes

- Read-only and safe — no confirmation needed to run the check battery itself; only the proposed `systemctl restart` needs the user's own hands.
- This is a **project-local** skill: it lives under the repo's `.claude/skills/` and is picked up directly. No `bosko-claude.nix` symlink or rebuild is required.
- `scripts/printer-diagnose.sh` holds the mechanical check battery; this file keeps the interpretation, which needs context (which host, recent switch history, Flatpak relaunch state) the script can't have on its own.

## Scripts

- `scripts/printer-diagnose.sh [printer-name-pattern]` — runs the avahi/config/queue/journal check battery (Step 2). Runs locally; the skill prefixes the whole invocation with the resolved SSH command for a remote host.
