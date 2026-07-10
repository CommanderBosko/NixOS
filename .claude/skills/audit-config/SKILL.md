---
name: audit-config
description: Use this skill when the user wants to "audit config", "audit the flake", "security audit", "bug audit", "review the whole config", "sweep for security issues", or "check my NixOS config for problems". Runs a structured security + correctness pass over the ENTIRE flake (not just the current diff), aware of this repo's intentional workarounds.
version: 0.2.0
---

# Audit Config

Run a structured security and correctness audit over the **whole** NixOS flake — not just the
pending diff. This is the "sweep the entire config" companion to the diff-scoped `/security-review`
and `/code-review` tools.

Use the built-in review tooling for diffs; use **this** skill when the user wants the standing
configuration as a whole examined.

## Arguments

- **scope** (optional) — narrows the audit to one host or area (e.g. "audit the server", "check
  the security module") instead of the whole flake. Parse it from the user's request if given; if
  omitted, default to the entire flake (see Step 0).

## When to prefer something else

- **Reviewing a branch or PR's changes** → use `/security-review` or `/code-review high` instead.
  Those are diff-scoped, maintained upstream, and faster. Tell the user and stop.
- **A deep, multi-angle cloud review of a branch** → that's `/code-review ultra` (user-triggered).
- This skill is for the *full config*, where there is no meaningful diff to anchor on.

## Step 0 — Establish scope

Confirm what to audit. Default to the entire flake. If the user named a host or area
(e.g. "audit the server", "check the security module"), narrow to that.

Read these first to ground the audit:

```bash
ls /home/bosko/NixOS/modules
ls /home/bosko/NixOS/hosts
```

Then read `flake.nix` to understand `mkSystem` and which modules each host composes.

## Step 1 — Know the intentional workarounds (do NOT flag these as bugs)

This repo has deliberate, documented deviations. Flagging them as findings is noise. Cross-check
every candidate finding against this list and against the project's memory files before reporting:

- **AppArmor PAM path workaround** (`modules/security.nix`): SDDM `include`
  directives are not `.so` paths. The `lib.mkForce` clearing of `rules` for `sddm` /
  `sddm-autologin`, with `text` overrides using `pkgs.linux-pam`, is **intentional** — it works
  around a nixpkgs bug. Not a finding.
- **Audit rules sentinel**: `security.audit.rules` must be non-empty; an empty list causes a
  blank-line parse error in audit-4.1.2. A comment sentinel rule is **intentional**. Not a finding.
- **`security.audit.enable` vs `security.auditd.enable`**: these are distinct (rules loader vs
  daemon). Don't report them as duplicated/confused options.
- **`nvidia.nix` imported per-host, not via `desktopModules`**: intentional, so gaming can drop it
  for the AMD card. Not a structural smell.
- **dbus-broker via plain assignment** (not `mkDefault`) in security.nix: intentional, beats
  nix-flatpak's `mkDefault`. Not a finding.
- Anything already explained in `CLAUDE.md` or the memory index at
  `/home/bosko/.claude/projects/-home-bosko-NixOS/memory/MEMORY.md`.

When in doubt whether something is intentional, read the relevant memory file before reporting it.

## Step 2 — Security pass

Walk the config looking for genuine security regressions. Focus areas, in rough priority:

1. **Secrets in the open** — private keys, passwords, tokens, WireGuard private keys, or API keys
   committed in plaintext. Run the sweep script to collect raw hits, then **triage** them:
   ```bash
   /home/bosko/NixOS/.claude/skills/audit-config/scripts/audit-sweep.sh
   ```
   Distinguish *option references* (e.g. `passwordFile = ...`, `.path`) from *literal embedded
   secrets*. Only literal embedded secrets are findings.
2. **Hardening regressions** — verify the security.nix guarantees are still in force across hosts:
   AppArmor enabled + `killUnconfinedConfinables`, audit daemon, PAM wheel enforcement for sudo,
   kexec disabled / kernel image protection, `kernel.randomize_va_space = 2` (full ASLR).
   Report anything silently disabled or overridden.
3. **Network exposure** — `networking.firewall` disabled or wide-open `allowedTCP/UDPPorts`,
   services bound to `0.0.0.0` that needn't be, SSH `PermitRootLogin`/`PasswordAuthentication`
   loosened. vpn-server (public-facing) is the highest-stakes here.
4. **Trust & privilege** — unexpected `nix.settings.trusted-users`, `security.sudo` wheel rules
   loosened, auto-login on hosts where it shouldn't be (note: SDDM auto-login on **gaming** is
   intentional/known — not a finding).
5. **Untrusted inputs / substituters** — unreviewed `nix.settings.substituters` or
   `trusted-public-keys` additions.

## Step 3 — Correctness / bug pass

Look for real bugs, not style:

- Options set on a host but silently overridden by a later `mkForce`/import (eval-order traps —
  this repo has a documented history of nix-flatpak module-order conflicts).
- Duplicate or conflicting option definitions across composed modules.
- Dead imports, references to files that don't exist, or modules added to git but not imported.
- Per-host drift: a hardening or fix applied to one host but missed on the others that should have
  it (compare the five hosts' `environment.nix` / `networking.nix`).
- Typos in option paths that Nix won't catch until eval.

To catch eval-level errors objectively, run the flake check. This is slow, so it's run
separately from the secret sweep — either directly or via the sweep script's optional flag:

```bash
/home/bosko/NixOS/.claude/skills/audit-config/scripts/audit-sweep.sh --flake-check
# (equivalent to: nix flake check /home/bosko/NixOS 2>&1)
```

Allow up to 5 minutes (300000ms timeout). Report any errors verbatim with file/line.

## Step 4 — Report

Produce a single prioritized report. For each finding:

- **Severity** — Critical / High / Medium / Low
- **Location** — `file_path:line`
- **What** — the issue in one sentence
- **Why** — the concrete risk or failure mode
- **Fix** — the specific change (option, value, or file edit)

Group by severity, Critical first. If nothing is found in a pass, say so explicitly
("Security pass: no findings") rather than omitting it — a clean pass is a result.

End with a one-line bottom line: is the config in good shape, or are there must-fix items?

Do **not** auto-apply fixes. This skill's job ends at the report — present findings and let the
user decide. If the user wants fixes applied, that is a separate follow-up action (their own
edit/commit flow, or a targeted skill like `/add-package` or `/pin-input` where one fits), not
something this skill does automatically.

## Script

`.claude/skills/audit-config/scripts/audit-sweep.sh [--flake-check]` — runs the deterministic
secret-pattern grep over all `*.nix` files and emits raw hits for the model to triage. With
`--flake-check` it also runs the slow `nix flake check`. The script does no triage and changes
nothing — judgment (Steps 1–4) stays with the model.

---

## Key facts

- Working directory: `/home/bosko/NixOS`
- Read-only by default — this skill audits and reports; it does not change the system.
- Scope is the **whole flake**; for diffs use `/security-review` or `/code-review`.
- Hosts: gaming, laptop, natalie-laptop, vpn-server (the four flake hosts). Shared system modules
  under `modules/`; shared HM configs under `dotfiles/`; host-specific files under `hosts/<host>/`.
- Always cross-check candidate findings against `CLAUDE.md` and the memory index before reporting,
  to avoid flagging this repo's documented intentional workarounds.
