# CLAUDE.md (Global)

Standing instructions for Claude Code across all projects, regardless of which repo is open.

## /init Also Runs claude-rules

Whenever `/init` is run, in any project, invoke the `claude-rules` skill immediately after `/init` finishes generating or updating that project's `CLAUDE.md` — don't treat `/init` as done until that check has run. `claude-rules` ensures the user's five standing workflow rules (Scope First, Verification Plan, Parallelize with Sub-Agents, Use Existing Skills First, Ask via AskUserQuestion) are present in the project's `CLAUDE.md`, adding any `/init`'s own pass left out, without touching what `/init` already wrote.
