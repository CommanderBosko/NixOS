---
name: ship-skill
description: Use this skill when the user says "ship this skill", "ship it", "build and ship a skill", "create and push a skill", or "ship-skill". Takes a new skill from draft through to a pushed commit in one flow — build, smoke-test, commit, then pause for confirmation before pushing.
version: 0.1.0
---

# Ship Skill

Orchestrate a new skill end to end: draft it, prove it works, commit it, and (with one confirmation) push it. (Bucket: Orchestration — chains `skill-suggestion` + `new-skill` + a smoke-test + `git-commit` + `git-push`, each an independent step that already stands alone.)

## Step 1 — Get a concrete skill spec

If the conversation already has a concrete skill idea (goal, name, scope, steps established), skip straight to Step 2 and pass that spec through — don't re-interview.

Otherwise, invoke the `skill-suggestion` skill and run **only its Step 4** (mine the conversation and, if nothing recent stands out, past transcripts; rank the candidates; propose them and get the user's pick via AskUserQuestion). Do **not** let it reach its Step 5: this skill's Step 2 is the single build, so `skill-suggestion` must not build a second copy.

## Step 2 — Build it

**Skip this step if the skill already exists.** Check both locations before building:

```bash
for d in /home/bosko/NixOS/dotfiles/bosko/claude/skills/<name> /home/bosko/NixOS/.claude/skills/<name>; do
  [ -d "$d" ] && echo "exists: $d"
done
```

If either path prints, do not build and do not overwrite it. Carry the existing directory into Step 3 and tell the user the build was skipped because it already exists.

Otherwise, hand off to the `new-skill` skill with the spec (goal, trigger phrases, scope, bucket, steps) pre-filled so the user isn't re-asked. This drafts and writes the SKILL.md (no Nix wiring is needed for global/repo-managed scope — `claude-hm/files.nix` auto-links every skill directory).

## Step 3 — Smoke-test it

Invoke the new skill once via the Skill tool against a safe, low-risk, or read-only scenario that exercises its documented steps end to end. Report plainly what happened — pass/fail, and any output that diverged from what the SKILL.md describes. If it fails, fix the skill file and re-test before moving on; don't commit a broken skill.

**Pre-rebuild fallback for global (repo-managed) skills.** A global skill under `dotfiles/bosko/claude/skills/<name>/` only reaches `~/.claude/skills/` after a rebuild is activated, so the Skill tool cannot invoke it yet. Smoke-test it from the repo copy instead:

1. Read `/home/bosko/NixOS/dotfiles/bosko/claude/skills/<name>/SKILL.md` and follow its documented steps by hand.
2. Run any helper scripts by their absolute repo path, e.g. `/home/bosko/NixOS/dotfiles/bosko/claude/skills/<name>/scripts/<script>`, never via `~/.claude`.
3. Report the result as "smoke-tested from repo copy, not via Skill tool", and note that the live invocation check is still pending the rebuild.

Project-local skills under `.claude/skills/<name>/` are invoked via the Skill tool as normal.

## Step 4 — Commit it

Hand off to the `git-commit` skill to stage and commit the new skill file(s) (staging matters: the flake only sees tracked files) plus a `CLAUDE.md` skills-list mention if one exists.

## Step 5 — Pause before pushing

Stop here and ask the user via **AskUserQuestion**: "Push now" or "Hold off, I'll push later". This is a deliberate checkpoint — unlike `git-push`'s own rule of skipping confirmation for unambiguous push requests, `ship-skill` has just made two consequential decisions back-to-back (built + committed) with no explicit user checkpoint since kicking off, so it pauses here rather than compounding a third.

- **Push now** — hand off to the `git-push` skill.
- **Hold off** — stop cleanly; report the commit hash for the user to push later themselves.

## Step 6 — Final report

Report: the skill name, where it was written, the smoke-test result, the commit hash, and whether it was pushed or is waiting on the user.

## Key facts

- For global/repo-managed skills, remind the user that the `~/.claude/skills/<name>/` symlink only appears once a rebuild is activated (`nh os switch`, or `nh os boot /home/bosko/NixOS` **+ reboot**) — it is not invocable via the Skill tool or a `/<name>` slash command until then. Step 3's pre-rebuild fallback covers the smoke test in the meantime.
- Never overwrite an existing skill directory: Step 2 is skipped when the name already exists.
- This skill does not skip Step 3's smoke-test even under time pressure — an untested skill committed to the repo is worse than no skill, since future sessions will trust and invoke it.
