# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-09-30 (session 119) — Pi-hole + famdash → NixOS migration scoped (plan only)

**Focus**: Decide whether and how to move the two Raspberry Pi 4s to NixOS, gather everything needed, and write the plan.

### What changed (and why)
- No repo changes. Three parallel read-only sub-agents inventoried the FamDash repo, the famdash Pi and the pi-hole Pi, so the plan rests on live state, not docs (the FamDash docs were stale on arch, revision and IP).
- Plan saved to memory (`project_pi_nixos_migration_plan.md`).

### Decisions
- famdash first, headless, stays on Wi-Fi (PSK via sops, user-captured); FamDash as SSH flake input since the repo is private.
- pi-hole: declarative lists replace `pihole-updatelists`, Teleporter import for client names/groups; 1.1.1.1 as temporary DNS during cutover; new Tailscale nodes; Tailscale + static LAN IP (the DHCP lease has drifted before).

### Issues / surprises
- pi-hole has no backup anywhere (single SD card). `bosko` has passwordless sudo there, contradicting an older memory note. famdash's live `db.json` is 136 KB; the repo copy is an 11 KB dev copy.

### Next session
- User takes the Teleporter backup + `db.json` copy, then start the famdash host.

**Commits**: none (planning session)

---

## Session: 2026-09-27/28 (session 118) — Manager-run `/flake-update-verify` lands as PR #29, merged

**Focus**: Have the `manager` agent run and land `/flake-update-verify`, then review CI and merge the result.

### What changed (and why)
- **`manager` agent ran `/flake-update-verify` non-interactively**, bumping nixpkgs, home-manager, dms (+ transitive dank-qml-common), and sops-nix. `nix flake check` + full `toplevel.drvPath` deep-eval both passed clean on all 4 hosts.
- **Landed as branch + PR (#29) instead of a direct push to `main`** — the manager agent has no `AskUserQuestion` as a background agent, so it substituted a human-reviewed PR for the skill's interactive commit gate, matching the 2026-09-07 precedent (PR #21). A documented, deliberate deviation, not a skipped check.
- **Both standing pins double-checked and left alone**: xwayland-satellite (0.8.1, fixed-commit input, byte-identical before/after) and vpn-server's `rtk` guard (unaffected — vpn-server pins `nixpkgs-stable`, which didn't move).
- **`public-repo-guard` ran its flake.lock-only-diff shortcut** (secret-scan + audit-config only) — 0 genuine findings.
- **Main session reviewed CI (green) and merged PR #29** as a merge commit (`3b61cf4`), deleted the branch, fast-forwarded local `main`.

### Decisions
- Accepted the manager's branch+PR substitution for the interactive commit gate as equivalent-in-intent (a human still reviews before `main` changes) — consistent with the 2026-09-07 precedent, not a new exception.

### Issues / surprises
- None — the manager flagged no ambiguity; both pins were verified rather than assumed untouched.

### Next session
- **All hosts: `/fleet-rollout`** to apply PR #29's bump — stacks onto the existing multi-bump (2026-09-07, 2026-09-20) + printer + skill rebuild backlog. No other action pending.

**Commits**: `136ac0e`..`3b61cf4` (2 commits: bump + merge)

---

## Session: 2026-09-27 (session 117) — `/dream` self-heals a real bug in its own wikilink resolver; weekly PR #28 merged

**Focus**: Close out a multi-day gap of Claude-ecosystem-only activity (2026-09-24 through 2026-09-27) — a routine pin re-check, the weekly `improve-system` review/merge cycle, and several `/dream` memory-mining passes, one of which surfaced and fixed a real bug in its own tooling.

### What changed (and why)
- **`improve-system` weekly sweep merged as PR #28** (`ba03b80`, via `manager`) — single-file MTU comment-citation fix in `new-peer`'s client template. A second, independent request to run `/improve-system` and merge correctly detected the work was already done and fast-forwarded instead of duplicating it.
- **`/dream` found and fixed a real bug in `find-memory-issues.sh`**: it resolved `[[wikilink]]`s only against a file's literal filename, but this account's memory corpus actually uses two conventions (farmer/screeps link via `name:` frontmatter, NixOS links via the filename stem) — the filename-only check false-positived on every farmer/screeps `name:`-slug link. Fixed to accept either, committed as `d466eb8`, confirmed live in the same session (no rebuild needed for a repo-managed skill symlink).
- **xwayland-satellite pin re-checked (2026-09-24)**: still holds at 0.8.1 — upstream shipped v0.8.3 with a matching-symptom fix, but it wasn't filed against the tracked issue #156, so the tracking issue itself is still open. No change to the pin.

### Decisions
- Fixed `find-memory-issues.sh` to accept both wikilink conventions rather than force one project's corpus to conform to the other's — see project-state.md Recent Decisions.

### Issues / surprises
- The first fix attempt for the wikilink bug (frontmatter-only resolution) broke NixOS's own memory dir before the dual-convention fix was found — worth remembering that this corpus genuinely has two valid conventions, not one right answer.

### Next session
- No repo/host action pending from this session; the laptop/natalie-laptop rebuild backlog carries over unchanged from session 116.

**Commits**: `d466eb8` (1 commit this session; `ba03b80` landed via a separate manager-agent PR merge)

---

## Session: 2026-09-23 (session 116) — Static declarative Canon printer queue replaces `cups-browsed`; xwayland-satellite pin re-checked

**Focus**: Diagnose and permanently fix a printer failure (jobs silently discarded, queue looked empty) reported live by the user, then a routine pin re-check and an informational model-choice question. This closes out a session that ran to completion before session-closer was invoked in a fresh conversation.

### What changed (and why)
- **Root cause was two stacked bugs**: `cups-browsed`'s auto-created queue hadn't survived a reboot since 2026-09-21 (a `network-online.target` fixup unit restarted it before the printer was resolvable, with no retry), and re-adding the printer by hand picked Gutenprint's "Apollo P-2100" PPD instead of the TS9500's — the Canon silently dropped every job while CUPS reported each one "completed."
- **Fixed by replacing `cups-browsed` outright** (`8085a0e`): `Canon_TS9500_series` is now a static `hardware.printers.ensurePrinters` entry with a checked-in driverless PPD and a `dnssd://` URI, set as default; `cups-browsed` and its fixup unit are disabled. This is the third fix attempt at the same underlying discovery-race symptom (session 71 partial fix, session 75 declined a timer mitigation) — replacing the mechanism instead of patching it again closes the failure class for good.
- **`printer-diagnose` skill rewritten** (`1c8c36e`) for the new setup, plus a real `pipefail`/`timeout` bug fix that was causing false "no IPP entries" reports.

### Decisions
- Replace `cups-browsed` entirely rather than add a fourth patch to its discovery-timing race — see project-state.md Recent Decisions for the full reasoning.

### Issues / surprises
- natalie-laptop's clock resets to November 2021 on cold boot until it syncs over the network — a likely dying CMOS/RTC battery, not fixable via config, and a plausible contributor to the original printer failures. Not acted on.

### Next session
- laptop + natalie-laptop: `git pull` + `nh os switch` to bring the printer fix live (laptop can't print at all until then).

**Commits**: `8085a0e..1c8c36e` (2 commits)

---

## Session: 2026-09-22 (session 115) — manager-run `/dream` + `/improve-system` (PR #26 merged), F1 governance resolution

**Focus**: Two `manager`-agent-overseen runs (`/dream`, `/improve-system`) and resolving a real governance contradiction the dream mining surfaced about pre-delegated merge authority.

### What changed (and why)
- **`/dream`**: mined 37 transcripts, 9 memory updates + 2 new files auto-applied (no repo changes). Flagged one real contradiction (F1) instead of auto-resolving it — see Decisions.
- **`/improve-system` → PR #26** (`8716fa2`): 16 verified skill-doc/script fixes across 13 skills + 7 new permission entries; closed the `review-improve-system-pr` `references/*` guardrail gap open since PR #25. CI went green, user merged.

### Decisions
- **F1 resolved by the user, not the agent**: pre-delegated merge authority ("merge if clean, flag if not") DOES satisfy a `manager` agent's ask-first gate going forward, even without `AskUserQuestion` reachable — PR #14 (2026-09-03) was the correct precedent; the 2026-09-22 classifier block was an overly-cautious outlier, not a new rule. Recorded in `project_review_improve_system_pr_skill.md`.
- Left the dream overview snapshot's `Status: PENDING_REVIEW` line untouched — twice blocked by the auto-mode classifier's instruction-poisoning heuristic, and the real resolution already lives in memory, so not worth fighting past.

### Issues / surprises
- Editing the dream overview file's `Status:` line specifically trips the auto-mode classifier (the file embeds parser-instruction comments) — a false positive on a file the user owns, not a real risk. No workaround applied; left as-is.

### Next session
- gaming: rebuild+reboot to bring PR #26's global skill fixes (`agent-suggestion`/`save-memory`/`session-closer`/`skill-suggestion`) live in `~/.claude`.

**Commits**: `8716fa2` (1 commit, PR #26 squash-merge)

---

