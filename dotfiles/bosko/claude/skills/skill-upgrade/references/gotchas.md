# Skill Upgrade — Gotchas

Load this before trusting a misfire scan's completeness, or before running Step 5's dry-run from outside `~/NixOS`.

- **`nixos-dry-run` is project-local to `~/NixOS`, not a global skill** — invoking it via the
  Skill tool from a different project's working directory fails with
  `Unknown skill: nixos-dry-run` (observed from a FinanceGuru session). When step 5 runs from
  outside `~/NixOS`, verify with the direct command instead:
  `nh os boot /home/bosko/NixOS --dry`.
- **`find-last-skill-invocation.sh` misses slash-command invocations.** It only greps for
  assistant-initiated `Skill` tool_use entries — when this skill (or the skill being fed to
  `find-skill-misfires.sh`'s `since-timestamp` arg in Step 1) is run the normal way, via a
  user-typed `/skill-upgrade`, Claude Code injects the instructions as user-turn content
  instead, so the detector never records it. `session-closer` already paid for this discovery
  for real (2026-08-02: reported a stale cutoff after two runs had actually happened since) —
  worth a mild irony flag, since fixing exactly this kind of undocumented gotcha in *other*
  skills is this skill's entire job. Cross-check a skill-specific commit marker in `git log`
  if the reported cutoff looks suspiciously old before trusting the misfire scan's scope.
  **Fixed 2026-08-10:** the script now also matches a `<command-name>/<skill-name></command-name>`
  slash-command turn (plain user-turn string content), not just `Skill` tool_use — this gotcha's
  workaround should be needed less going forward, but keep the cross-check habit since other gaps
  may still exist.
- **Step 2 mis-resolved a project-local-only skill as global.** Tried to `Read`
  `~/.claude/skills/new-background-loop/SKILL.md` for a skill that only exists at
  `.claude/skills/new-background-loop/SKILL.md` in the bitburner project — no global copy exists
  at all — and got `File does not exist`. Same failure class as the `nixos-dry-run` gotcha above,
  just recurring against a different skill. Step 2's instructions above now say to check
  project-local first for this reason.
- **Step 2's own "find its source `SKILL.md`" hit the compound-predicate `find` failure.** Ran
  `find /home/bosko/NixOS -path "*dotfiles/.../skill-upgrade*" -o -path "*dotfiles/.../new-skill*"`
  to locate two skills' repo copies at once; `rtk find` rejected it outright (`does not support
  compound predicates or actions`) — the exact failure class the user's global CLAUDE.md flags as
  "the single most common tool-call failure across this user's projects." Recovered by switching
  to `grep -n <pattern> <file1> <file2>` against the already-known repo-managed paths, but wasted
  a turn first. When locating one or more flagged skills' source files in Step 2, go straight to
  `grep`/one `find` call per skill (never `-o`/`-not`/`-exec`) instead of trying to combine paths
  in a single `find`.
