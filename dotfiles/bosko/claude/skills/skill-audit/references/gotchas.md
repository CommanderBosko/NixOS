# Skill Audit — Gotchas

Load this before trusting Step 0's cutoff or Step 1's script path.

- **Don't trust inline tables as ground truth.** Duplicated constants drift; the skill's own documentation can be the stale copy. We once found a skill documenting the wrong SSH user — the "wrong-looking" script was actually right.
- **Disjoint partitions matter.** If two sub-agents edit the same skill, their changes collide. Partition so each skill (and its future edits) has exactly one owner.
- **Global vs project-local is the overhead axis.** Script/asset/reference extraction is free for project-local skills, but costs a `git add` + rebuild for global ones (no Nix wiring — `claude-hm/files.nix` auto-links every skill directory). Weigh that before recommending it.
- **A clean skill is a result.** Say "clean on all 7" in one line rather than inventing findings.
- **`find-last-skill-invocation.sh` misses slash-command invocations.** It only greps for
  assistant-initiated `Skill` tool_use entries — when this skill is run the normal way, via a
  user-typed `/skill-audit`, Claude Code injects the instructions as user-turn content instead,
  so the detector never records it. `session-closer` hit this for real (2026-08-02: reported a
  stale cutoff when two runs had actually happened since); this skill's own Step 0 uses the
  identical detector for the same scoping purpose. Cross-check
  `git log --oneline --grep 'skill-audit\|audit sweep' -i | head -1` (or any other
  audit-specific commit marker) if the reported cutoff looks suspiciously old — a stale
  cutoff just means Step 0 scopes too wide (extra transcripts to skim), not a wrong audit, but
  it's still worth catching before assuming "last run" is accurate. **Fixed 2026-08-10:** the
  script now also matches a `<command-name>/<skill-name></command-name>` slash-command turn
  (plain user-turn string content), not just `Skill` tool_use — this gotcha's workaround
  should be needed less going forward, but keep the cross-check habit since other gaps may
  still exist.
- **`enumerate-skills.sh` lives in the SKILL's base dir, not the repo** (observed 2026-07-02): invoking `scripts/enumerate-skills.sh` relative to the repo root fails — the repo's `scripts/` is empty. Run `bash <skill-base-dir>/scripts/enumerate-skills.sh` (the base dir is printed when the skill loads), with the repo root as cwd.
- **Don't schedule wakeups for sub-agent waits.** Twice in one session (2026-09-13-ish window), a `ScheduleWakeup` fallback heartbeat while Step 2's forks ran errored with `` `prompt` is required when `stop` is not true ``. The heartbeat was never needed: the harness notifies on sub-agent completion, so let the turn end after spawning (same rule as `research`'s `references/gotchas.md`).
