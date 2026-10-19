---
name: git-commit
description: Stage and commit current changes to git with a meaningful commit message. Use when the user says "commit", "git commit", "save my changes", or "commit to github".
---

# Git Commit Skill

Stage and commit all current changes with a well-crafted commit message.

## Steps

1. Run `/home/bosko/.claude/skills/git-commit/scripts/git-commit.sh status` (the absolute path — see Gotchas, a bare `scripts/...` path 404s) — prints `git status`, `git diff`, and `git log --oneline -5` in one call, to understand what changed and match the repo's commit message style.
2. Check for unrelated uncommitted work: compare the files `git status` shows against what the
   current task actually touched. If everything belongs to the current task, skip straight to step 3.
   If there's anything else — modified or untracked, doesn't matter — flag it to the user via the
   **AskUserQuestion** tool (don't just silently leave it out, and don't fold it in unasked) with
   options **Commit it too** / **Leave it alone for now**. Only ask about the extras — never ask
   for permission on the files the current task actually changed, that's still automatic per step 4.
   If the user says to commit the extras too, treat them as their own separate commit (their own
   message, their own `git-commit.sh commit` call) rather than mixing them into the task's
   commit message, unless they're clearly the same change.
3. Analyze the changes:
   - Summarize the nature of the change (new feature, bug fix, refactor, docs, etc.)
   - Draft a concise commit message focused on the "why" not the "what"
   - Do NOT commit files that likely contain secrets (.env, .screeps.json, credentials, tokens)
   - Warn the user if any sensitive files are staged
4. Show the drafted message, then **proceed straight to staging and committing** — do not pause for
   a "confirm or edit?" approval step. Draft and commit immediately without asking for sign-off
   (standing user preference, not specific to any one project). The only exception is if the user
   explicitly asked to review the message first.
5. Stage and commit by running `/home/bosko/.claude/skills/git-commit/scripts/git-commit.sh commit <file>...` — name specific changed
   files explicitly (avoid staging everything unless all changes are clearly safe) — and pipe the
   commit message in via a HEREDOC on stdin so formatting (including the blank line before the
   trailer) is preserved exactly:

```bash
/home/bosko/.claude/skills/git-commit/scripts/git-commit.sh commit <file1> <file2> <<'EOF'
<message here>

<trailer line(s) here>
EOF
```

Append whatever commit-message attribution trailer line(s) the harness's own current-session
instructions specify — not just a single `Co-Authored-By: <model> <noreply@anthropic.com>` line.
Some sessions require more than one trailer line (e.g. an additional `Claude-Session: <url>`
line); copy the harness's instructions for this session verbatim rather than assuming a fixed
one-line shape. Likewise don't hardcode a specific model name — it will drift the next time the
underlying model changes.

The script stages exactly the files you name, commits with that message, then prints `git status`
again to confirm.

6. Report: what was committed, the commit hash, and the message used. If step 2 turned up extras
   that got their own commit, report that separately too.

## Rules

- Never use `--no-verify` unless the user explicitly asks
- Never amend a previous commit unless the user explicitly asks
- If there are no changes to commit, say so — do not create an empty commit
- If a pre-commit hook fails, fix the underlying issue and create a NEW commit (never --amend after a hook failure)

## Gotchas

- **Script paths:** use the absolute path from this skill's Base directory line, never a bare `scripts/...` — see `~/.claude/skills/lib/script-paths.md`.
