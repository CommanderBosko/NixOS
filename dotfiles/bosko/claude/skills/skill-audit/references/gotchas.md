# Skill Audit — Gotchas

Load this before trusting Step 0's cutoff or Step 1's script path.

- **Don't trust inline tables as ground truth.** Duplicated constants drift; the skill's own documentation can be the stale copy. We once found a skill documenting the wrong SSH user — the "wrong-looking" script was actually right.
- **Disjoint partitions matter.** If two sub-agents edit the same skill, their changes collide. Partition so each skill (and its future edits) has exactly one owner.
- **Global vs project-local is the overhead axis.** Script/asset/reference extraction is free for project-local skills, but costs a `git add` + rebuild for global ones (no Nix wiring — `claude-hm/files.nix` auto-links every skill directory). Weigh that before recommending it.
- **(Historical — no longer applies since `claude-hm/files.nix` auto-links every skill dir recursively.) A global skill's existing entry could be the file-by-file form, not recursive.** Found 2026-09-16, during the CLAUDE.md/skills lightweight-context pass: `research`, `agent-suggestion`, `improve-system`, and `session-analysis` were each wired in `bosko-claude.nix` with the file-by-file form (`".claude/skills/<name>/SKILL.md" = { source = ...; force = true; }`), which only symlinks `SKILL.md` itself — a first `scripts/`, `assets/`, or `references/` file would have been invisible in `~/.claude` even after a rebuild. **Fixed the same day** — all four were converted to the recursive directory form (`".claude/skills/<name>" = { source = ...; recursive = true; force = true; }`); re-verified current as of the 2026-09-16 audit re-check. The old per-skill `home.file` entries are gone entirely (skills are now discovered from the directory listing), so there is no entry to check any more — a new script/asset/reference under a global skill just needs a `git add` + rebuild.
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
  it's still worth catching before assuming "last run" is accurate. **Fixed 2026-08-10:** the
  script now also matches a `<command-name>/<skill-name></command-name>` slash-command turn
  (plain user-turn string content), not just `Skill` tool_use — this gotcha's workaround
  should be needed less going forward, but keep the cross-check habit since other gaps may
  still exist.
- **`enumerate-skills.sh` lives in the SKILL's base dir, not the repo** (observed 2026-07-02): invoking `scripts/enumerate-skills.sh` relative to the repo root fails — the repo's `scripts/` is empty. Run `bash <skill-base-dir>/scripts/enumerate-skills.sh` (the base dir is printed when the skill loads), with the repo root as cwd.
- **`ScheduleWakeup` fallback-heartbeat calls for background fork/sub-agent sweeps omitted the required `prompt` param.** Recurred twice in one session (2026-09-13-ish window): a `noop:true` call with no `stop:true` needs `prompt` set too (it re-enters the loop on wake), and both attempts — one waiting on 5 parallel skill-audit forks, one for a general background-agent fallback — errored with `` `prompt` is required when `stop` is not true `` before self-correcting. When scheduling a fallback wakeup while background forks are still running, always pass a non-empty `prompt` alongside `delaySeconds`/`reason`/`noop`, even for a pure "check back later" heartbeat.
