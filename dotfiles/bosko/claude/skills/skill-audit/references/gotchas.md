# Skill Audit — Gotchas

Load this before trusting Step 0's cutoff or Step 1's script path.

- **Don't trust inline tables as ground truth.** Duplicated constants drift; the skill's own documentation can be the stale copy. We once found a skill documenting the wrong SSH user — the "wrong-looking" script was actually right.
- **Disjoint partitions matter.** If two sub-agents edit the same skill, their changes collide. Partition so each skill (and its future edits) has exactly one owner.
- **Global vs project-local is the overhead axis.** Script/asset extraction is free for project-local skills, but costs a symlink entry + rebuild for global ones. Weigh that before recommending it.
- **A clean skill is a result.** Say "clean on all 6" in one line rather than inventing findings.
- **`find-last-skill-invocation.sh` misses slash-command invocations.** It only greps for
  assistant-initiated `Skill` tool_use entries — when this skill is run the normal way, via a
  user-typed `/skill-audit`, Claude Code injects the instructions as user-turn content instead,
  so the detector never records it. `session-closer` hit this for real (2026-08-02: reported a
  stale cutoff when two runs had actually happened since); this skill's own Step 0 uses the
  identical detector for the same scoping purpose. Cross-check
  `git log --oneline --grep 'skill-audit\|audit sweep' -i | head -1` (or any other
  audit-specific commit marker) if the reported cutoff looks suspiciously old — a stale
  cutoff just means Step 0 scopes too wide (extra transcripts to skim), not a wrong audit, but
  it's still worth catching before assuming "last run" is accurate.
- **`enumerate-skills.sh` lives in the SKILL's base dir, not the repo** (observed 2026-07-02): invoking `scripts/enumerate-skills.sh` relative to the repo root fails — the repo's `scripts/` is empty. Run `bash <skill-base-dir>/scripts/enumerate-skills.sh` (the base dir is printed when the skill loads), with the repo root as cwd.
