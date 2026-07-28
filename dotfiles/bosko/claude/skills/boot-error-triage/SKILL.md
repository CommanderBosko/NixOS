---
name: boot-error-triage
description: Triage a host's boot log end-to-end and root-cause a warning or error down to a real fix — severity-filtered journal scan, noise filtering, hardware/firmware cross-reference, and an external lookup if it looks like a known quirk. Use when the user says "diagnose this boot warning", "why is the boot log noisy", "root-cause this kernel error", "check the boot logs" (when they want more than a clean/dirty verdict), or "figure out what's wrong at boot".
---

# Boot Error Triage

Turn a vague "boot log is spammy / something's wrong" into a root-caused fix, on whichever host you're currently on. (Bucket: Orchestration — coordinates a diagnostic sweep, an external lookup, and (on confirmation) a hand-off to `nixos-dry-run` and `git-commit`.)

Distinct from the `journal` skill: `journal` tails recent log lines for one **already-known** service name. This skill's job is different — triage an entire boot for *unknown* problems and chase one down to a root cause and a fix.

## Steps

### 1. Collect boot diagnostics

Run the collection script — it's a fixed sequence of read-only commands, no judgment involved:

```bash
scripts/collect-boot-diagnostics.sh
```

(Path is relative to this skill's own directory — see the "Base directory" line shown when the skill loads. Resolve the full absolute path rather than guessing a project-relative one; see the `git-commit` skill's Gotchas for why that assumption reliably breaks.)

It prints, in order: `systemctl --failed`, boot timing (`systemd-analyze`), priority ≤3 (error+) and priority ≤2 (crit+) journal lines for the current boot, then hardware/firmware identity (`lscpu`, `/proc/cmdline`, `uname -r`, and the board/BIOS fields from `/sys/class/dmi/id/`).

### 2. Filter noise, isolate real candidates

Boot logs carry known-benign noise — e.g. `dbus-broker-launch: Ignoring duplicate name` lines (multiple portal packages shipping the same D-Bus service name) or `gkr-pam: unable to locate daemon control file`. Filter these out mentally (or with `grep -v`) and separate what's left into: failed systemd units (real, urgent) vs. kernel/driver warnings (may be cosmetic).

### 3. Check live subsystem state

For each real candidate, check whether the kernel already recovered gracefully or whether there's an active outage — e.g. for a failed driver probe, check the fallback that's actually active (`cat /sys/.../scaling_driver`, `lsmod`, `systemctl is-active <unit>`). A clean fallback with no functional impact changes the urgency of the fix, not whether it's worth understanding.

### 4. Cross-reference against known hardware/firmware quirks

If a warning looks tied to specific hardware (a CPU generation, a GPU, a motherboard's firmware), use the identity info from step 1 to look it up: `WebSearch` for the CPU/GPU/board model plus the exact error string, and `WebFetch` a vendor changelog or support page if one turns up, to check whether a newer firmware or kernel parameter is the known fix.

### 5. Weigh the fix options with the user

Present the options found — cosmetic/config-only fix (e.g. a `boot.kernelParams` flag to skip a known-failing probe), a firmware/driver update (higher risk, often a manual/physical action outside what you can perform or verify remotely), or leaving it as-is if the impact is purely cosmetic. Use the **AskUserQuestion** tool to let the user pick — this is a real tradeoff decision, not a status report. Flag explicitly if a firmware path is irreversible-if-interrupted (e.g. a board with no BIOS Flashback recovery button) — that's a reason to lean toward the config-only fix by default, not a reason to avoid mentioning the firmware option.

### 6. Apply the chosen fix

If a config-only fix is chosen, find the right host file — check for an existing host-specific file that already covers the same subsystem (e.g. `hosts/<host>/virtualisation.nix` for IOMMU-related params) before adding a new `boot.kernelParams` block to `hosts/<host>/environment.nix`. Add a short comment explaining the non-obvious hardware reason, not what the flag does.

### 7. Verify and hand off

Run the `nixos-dry-run` skill to confirm the config still evaluates. Report the change and, only if the user wants it committed, hand off to `git-commit`.

## Scripts

- `scripts/collect-boot-diagnostics.sh` — runs the fixed diagnostic command sequence for step 1 (failed units, boot timing, priority-filtered journal, hardware/firmware identity). No arguments; always reads the local host's current boot.
