# CLAUDE.md (Global)

Standing instructions for Claude Code across all projects, regardless of which repo is open.

## /init Also Runs claude-rules

Whenever `/init` is run, in any project, invoke the `claude-rules` skill immediately after `/init` finishes generating or updating that project's `CLAUDE.md` — don't treat `/init` as done until that check has run. `claude-rules` ensures the user's five standing workflow rules (Scope First, Verification Plan, Parallelize with Sub-Agents, Use Existing Skills First, Ask via AskUserQuestion) are present in the project's `CLAUDE.md`, adding any `/init`'s own pass left out, without touching what `/init` already wrote.

## `find` Only Takes One `-iname` Predicate

The `find` in this environment (`rtk find`) rejects compound predicates outright — no `-o`, `-not`, or `-exec`. A command like `find . -iname "a.md" -o -iname "b.md"` or `find . -not -path "*/node_modules/*"` fails with `rtk: rtk find does not support compound predicates or actions`, not a normal "no matches" exit. Issue one `-iname`/`-name` pattern per `find` call instead — run multiple separate calls (in parallel if independent) rather than combining patterns, and use `grep`/a pipeline for exclusions instead of `-not`/`-exec`. This has been the single most common tool-call failure across this user's projects — check for a compound predicate first whenever a `find` call errors instead of assuming "no matches" or a path typo.

## Stale Fast-Moving Research Memories

The `research` skill writes `reference`-type memories tagged with a `Volatility: fast|slow` line (see `dotfiles/bosko/claude/skills/research/SKILL.md`). Whenever such a memory surfaces in context — auto-loaded from a project's `MEMORY.md` index at session start, or read directly during the conversation — and its body carries `Volatility: fast`, check its `Researched: YYYY-MM-DD` date. If that date is more than 90 days old, proactively tell the user it looks stale before relying on it, and offer to refresh it with `/research <topic>`. Do **not** do this for memories tagged `Volatility: slow` (settled topics — e.g. history, definitions) no matter how old they are, and don't do it for non-research memories that carry no `Volatility` tag at all — this rule only applies to memories the `research` skill itself marked fast-moving.
