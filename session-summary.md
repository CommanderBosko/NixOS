# Session Summary Log

_Older entries are in [session-summary-archive.md](session-summary-archive.md)._

---

## Session: 2026-08-24 (session 91) — Removed gemini-cli from all hosts and users

**Focus**: Drop `gemini-cli` entirely — no longer in use.

### What changed (and why)
- Removed `gemini-cli` from `modules/users.nix` for both `bosko` and `natty` — the only 2 references in the whole repo, both in this shared module (`commonModules`, so it covers all 4 hosts). `natty`'s package list is now empty.
- Updated `README.md` (user-packages bullet, Users table, Recent Changes) to match; left historical mentions in `session-summary-archive.md` and `.claude/loops/flake-update-verify/` run logs alone as point-in-time records.

### Decisions
- Retired session 74/78's "leave the removal warning as-is" call along with the package — that nixpkgs `meta.problems.removal` eval warning (Google deprecating Gemini CLI for Antigravity CLI) is now moot.
- Didn't touch `session-summary-archive.md` or old loop output/memory logs — those record what was true at the time, not live config.

### Issues / surprises
- None.

### Next session
- All 4 hosts still need a `switch`/`boot` to actually drop the package from the store (pure package-list change, no reboot required).

**Commits**: `406b373` (1 commit)

---

## Session: 2026-08-24 — Auto Mode setup made declarative across all hosts

**Focus**: Figure out why laptop needed its own manual `/auto-mode-setup` run despite Auto
Mode supposedly being "global," then fix it so no host ever needs the manual pass again.

### What changed (and why)
- Confirmed gaming's `~/.claude/settings.json` already had the full `defaultMode`/`autoMode`
  policy from an earlier setup — nothing to gain from re-running `/auto-mode-setup` there.
- Root-caused the laptop confusion: "global" in the prior session's memory meant global
  *across projects on one machine*, not across hosts — `~/.claude/settings.json` is
  per-machine runtime state, so each host needs its own `/auto-mode-setup` pass.
- User asked to have gaming's setup applied to laptop and natalie-laptop too. Instead of
  another manual pass, added a `home.activation.claudeAutoMode` block to
  `dotfiles/bosko/bosko-claude.nix` that full-reconciles `permissions.defaultMode="auto"`
  plus the entire `autoMode.soft_deny`/`environment` policy into `~/.claude/settings.json`
  on every rebuild — same full-reconcile pattern as the existing `claudeMcpServers` block.

### Decisions
- Full-reconcile (overwrite to canonical), not additive merge — autoMode is repo policy,
  not user-editable state, matching the file's existing `claudeMcpServers` convention over
  its `claudeAllowList` one.
- vpn-server correctly excluded — no home-manager `bosko` user there, confirmed via
  `modules/home-manager.nix`, so this only reaches gaming/laptop/natalie-laptop.

### Issues / surprises
- First implementation attempt shell-interpolated the JSON via a bash single-quoted string;
  broke because several `environment` strings contain apostrophes ("this repo's stated
  normal flow") that prematurely closed the quote — `nh os boot --dry` failed with a bash
  syntax error. Fixed with `pkgs.writeText` + `jq --slurpfile`, which avoids shell quoting
  of the content entirely.

### Next session
- laptop and natalie-laptop: pull + rebuild to pick up `f01382b` (user says they'll handle
  this themselves).

**Commits**: `f01382b` (1 commit)

---

## Session: 2026-08-23 — Real fix for the CIFS mount-timeout stall (missing hyphen)

**Focus**: Session 86's fix for the `/srv/shared` terminal-stall bug turned out to be a
silent no-op — track down why, fix it for real, verify live.

### What changed (and why)
- User reported the ~10s terminal freeze (whenever `gaming` is off/unreachable) was still
  happening after session 86's fix. Found the fix never actually applied: it wrote
  `x-systemd.mounttimeout=2` (no hyphen) in `modules/shared-folder-client.nix`, but the real
  fstab keyword is `x-systemd.mount-timeout` (hyphenated, per `man systemd.mount`) — fstab
  silently drops unrecognized options instead of erroring, so the 10→2s change never took
  effect. `systemctl show srv-shared.mount` was the tell: `TimeoutUSec` still read systemd's
  90s default even on the switched-in generation.
- Fixed in two commits: `86ad36e` (first attempted the timeout drop, still with the typo)
  then `24a1d2d` (corrected the hyphen). Also ruled out a user-raised alacritty-vs-kitty
  angle — the trigger is starship on every prompt redraw, not terminal-specific; alacritty
  isn't even installed on this system.

### Decisions
- Kept the shrink-not-eliminate scope from session 86 rather than chasing why
  starship/DMS touch `/srv/shared` at all when it's unreachable — same tradeoff, still holds.

### Issues / surprises
- A previously "verified and pushed" fix silently never took effect for a whole session —
  fstab's silent-drop behavior on unrecognized `x-systemd.*` options means a dry-run/deep-eval
  pass proves the config *evaluates*, not that the option is actually a real, honored keyword.

### Next session
- **natalie-laptop still needs its own `nh os switch`/`nh os boot`** to pick up
  `86ad36e`+`24a1d2d` (shares this module with laptop, not yet rebuilt with either commit).
  laptop itself is confirmed live and verified (`TimeoutUSec` reads `2s`, real stall now ~2s).

**Commits**: `86ad36e..24a1d2d` (2 commits)

---

## Session: 2026-08-23 — No-op close (immediate re-run after prior close)

**Focus**: `/session-closer` was invoked again right after the same-day close below, with no
work done in between — a review/no-op session, not a coding one.

### What changed (and why)
- Nothing. `git status` clean, no commits since the `8915985` baseline (itself this same
  day's prior close). `project-state.md` and `README.md` are left as-is since nothing
  changed since they were last refreshed a few minutes earlier.

### Next session
- Same open items as the prior 2026-08-23 entry below (rebuild to bring `3230dfd` live,
  apply the `041a0d1` flake bump + pending `ssh.nix` switch).

**Commits**: none (clean tree)

---

## Session: 2026-08-23 — Research-skill memory feature, flake bump, gaming boot re-triage

**Focus**: Make `/research` persist its findings to memory (with prior-research cross-referencing and a staleness tag); catch-up close for a same-arc flake bump, a clean gaming boot triage, and a live WarDogs crash diagnosis.

### What changed (and why)
- `dotfiles/bosko/claude/skills/research/SKILL.md` (`3230dfd`): Step 2 now checks the project's memory dir for a prior finding on the topic before searching; Step 6 states whether new results reaffirm/update/contradict it; Step 7 persists sources+consensus+coverage to a `reference` memory via `save-memory`, tagged with a judged `Volatility: fast|slow` line so a later stale read can be flagged.
- `dotfiles/bosko/claude/CLAUDE.md` (`3230dfd`): new "Stale Fast-Moving Research Memories" rule — proactively flags a recalled `Volatility: fast` memory older than 90 days as possibly stale.
- `flake.lock` (`041a0d1`, via `/flake-update-verify`): nixpkgs/home-manager/dms bumped, verified clean (flake-check + 4-host deep-eval), committed+pushed lock-only.

### Decisions
- No architectural decisions this session — mostly additive feature work and routine verification.

### Issues / surprises
- `/boot-error-triage` re-run on gaming (testing the new Concise output style) came back clean — same benign AMD IRQ quirk as before, now memory-suppressed from re-flagging; user again declined the BIOS flash.
- A live WarDogs "freeze" turned out to be a `GameThread` SIGSEGV followed by a 2-minute `systemd-coredump` write, not an actual hang — no config change, diagnostic only.

### Next session
- Rebuild + reboot gaming (or any host) to bring `3230dfd`'s research-skill/CLAUDE.md changes live in `~/.claude`.
- Apply the `041a0d1` flake bump and the still-pending `ssh.nix` Tailscale-IP switch (session 87) — both can ride the same rebuild.

**Commits**: `041a0d1..3230dfd` (2 commits)

---

