# Canonical Rule Blocks

When a rule section is missing from a project's `CLAUDE.md`, insert the matching block below **verbatim**. Do not rewrite or "improve" the wording — these are the agreed canonical versions.

## Scope First (Interview)

```markdown
## Scope First (Interview)

Use the `/interview` skill to pin down the real goal with the user before starting work whose scope or target is genuinely unclear — don't build against a guessed-at understanding of the request when guessing wrong would mean redoing the work. Skip it when the ask is already concrete (a single, already-diagnosed fix, a narrowly-scoped request) — a few blocking clarifying questions are enough there. When you do run it, surface the unknowns, confirm scope and constraints, and only proceed once the target is clear. Do this in tandem with the Verification Plan below: the interview establishes *what* we're building and how we'll know it's done, and the verification plan establishes *how we'll prove* it works.
```

## Verification Plan

```markdown
## Verification Plan

Before you do any work, state how you'll verify it with the `/verify` skill — say up front how you'll confirm each part actually works before calling it done. Pick the checks that fit this project (build, test suite, linter, type-check, running the app, hitting the endpoint, reading the logs) and name the specific commands. Lay out the plan with the work, not after it.
```

## Parallelize with Sub-Agents

```markdown
## Parallelize with Sub-Agents

**This rule is your standing authorization to spawn sub-agents — you do not need to ask first.** Once scope and the verification plan are set, before starting any task with more than one independent part, stop and run a parallelization check. This is a required step, not an aspiration: ask "Can I split this into pieces that don't depend on each other's output?" If yes, spawn one sub-agent per piece in a single message and let them run concurrently.

Each spawned sub-agent must stay strictly inside the piece it was assigned — the exact file list or task boundary given in its prompt — and must not wander into a sibling agent's piece or the synthesis step reserved for you. A sub-agent that does more than its assigned slice (e.g. re-reading files assigned to another agent, or drawing conclusions across the whole task instead of just its piece) has gone out of scope, not "being extra helpful" — treat that as a bug to correct, the same way you would a wrong file edit.

Trigger parallelization whenever you hit any of these:
- About to research, search, or read across 2+ areas of the tree that don't depend on each other.
- About to scaffold or draft 2+ files whose *contents* don't reference each other.
- You catch yourself planning "do A, then B, then C" where B doesn't need A's result.

Reserve serial work for genuine dependencies — e.g. a new file and the line elsewhere that imports it are coupled, so keep them together. When the pieces are independent, default to fanning out breadth-first; state in your plan which pieces run in parallel and why.
```

## Use Existing Skills First

```markdown
## Use Existing Skills First

Before doing a task by hand, check whether an existing skill already covers it and invoke it instead of improvising. Skills encode the agreed, repeatable way to do a thing — prefer them over ad-hoc steps. If you find yourself doing the same multi-step task a second time and no skill exists, offer to create one.
```

## Ask via AskUserQuestion

```markdown
## Ask via AskUserQuestion

When you need a decision, choice, or clarification from the user — not just information you can look up yourself — use the **AskUserQuestion** tool rather than asking in plain text. Phrase it as 2-4 concrete options (with a recommended one first); when the answer could be open-ended, the tool's built-in "Other" choice covers free text. This keeps answers structured, makes trade-offs explicit, and avoids an answer getting buried in prose. Reserve plain-text questions for genuinely open, generative prompts where no sensible options exist yet (e.g. "describe the project in your own words").
```
