# Skill Audit — Gotchas

Load this before trusting Step 0's cutoff or Step 1's script path.

- **Don't trust inline tables as ground truth.** Duplicated constants drift; the skill's own documentation can be the stale copy. We once found a skill documenting the wrong SSH user — the "wrong-looking" script was actually right.
- **Disjoint partitions matter.** If two sub-agents edit the same skill, their changes collide. Partition so each skill (and its future edits) has exactly one owner.
- **Global vs project-local is the overhead axis.** Script/asset/reference extraction is free for project-local skills, but costs a symlink entry + rebuild for global ones. Weigh that before recommending it.
- **A global skill's existing entry can be the file-by-file form, not recursive — check before recommending a new sibling file.** Found for real 2026-09-16, during the CLAUDE.md/skills lightweight-context pass: `research`, `agent-suggestion`, and `improve-system` were each wired in `bosko-claude.nix` with the file-by-file form (`".claude/skills/<name>/SKILL.md" = { source = ...; force = true; }`), which only symlinks `SKILL.md` itself. Giving any of them a first `scripts/`, `assets/`, or `references/` file would have left that file invisible in `~/.claude` even after a full rebuild — the entry has to be converted to the recursive directory form (`".claude/skills/<name>" = { source = ...; recursive = true; force = true; }`) first. Before recommending (or making) any script/asset/reference extraction for a global skill, grep its current `home.file` entry in `bosko-claude.nix` and confirm it's already recursive, or flag the conversion as part of the fix.
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
