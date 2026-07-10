---
name: ship-skill
description: Use this skill when the user says "ship this skill", "ship it", "build and ship a skill", "create and push a skill", or "ship-skill". Takes a new skill from draft through to a pushed commit in one flow — build, smoke-test, commit, then pause for confirmation before pushing.
version: 0.1.0
---

# Ship Skill

Orchestrate a new skill end to end: draft it, prove it works, commit it, and (with one confirmation) push it. (Bucket: Orchestration — chains `skill-suggestion` + `new-skill` + a smoke-test + `git-commit` + `git-push`, each an independent step that already stands alone.)

## Step 1 — Get a concrete skill spec

If the conversation already has a concrete skill idea (goal, name, scope, steps established), skip straight to Step 2 and pass that spec through — don't re-interview.

Otherwise, hand off to the `skill-suggestion` skill to mine the conversation (and, if nothing recent stands out, past session transcripts) for the best candidate, and get the user's go-ahead on it.

## Step 2 — Build it

Hand off to the `new-skill` skill with the spec (goal, trigger phrases, scope, bucket, steps) pre-filled so the user isn't re-asked. This drafts and writes the SKILL.md and, for global/repo-managed scope, adds the `bosko-claude.nix` wiring.

## Step 3 — Smoke-test it

Invoke the new skill once via the Skill tool against a safe, low-risk, or read-only scenario that exercises its documented steps end to end. Report plainly what happened — pass/fail, and any output that diverged from what the SKILL.md describes. If it fails, fix the skill file and re-test before moving on; don't commit a broken skill.

## Step 4 — Commit it

Hand off to the `git-commit` skill to stage and commit the new skill file(s) plus any wiring changes (`bosko-claude.nix`, a `CLAUDE.md` skills-list mention if one exists).

## Step 5 — Pause before pushing

Stop here and ask the user via **AskUserQuestion**: "Push now" or "Hold off, I'll push later". This is a deliberate checkpoint — unlike `git-push`'s own rule of skipping confirmation for unambiguous push requests, `ship-skill` has just made two consequential decisions back-to-back (built + committed) with no explicit user checkpoint since kicking off, so it pauses here rather than compounding a third.

- **Push now** — hand off to the `git-push` skill.
- **Hold off** — stop cleanly; report the commit hash for the user to push later themselves.

## Step 6 — Final report

Report: the skill name, where it was written, the smoke-test result, the commit hash, and whether it was pushed or is waiting on the user.

## Key facts

- For global/repo-managed skills, remind the user that the `~/.claude/skills/<name>/` symlink only appears after `nh os boot /home/bosko/NixOS` **+ reboot** — the repo copy works in the meantime when invoked from within this repo.
- This skill does not skip Step 3's smoke-test even under time pressure — an untested skill committed to the repo is worse than no skill, since future sessions will trust and invoke it.
