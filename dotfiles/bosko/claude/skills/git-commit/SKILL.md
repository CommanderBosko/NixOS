---
name: git-commit
description: Stage and commit current changes to git with a meaningful commit message. Use when the user says "commit", "git commit", "save my changes", or "commit to github".
---

# Git Commit Skill

Stage and commit all current changes with a well-crafted commit message.

## Steps

1. Run `git status` and `git diff` in parallel to understand what changed.
2. Run `git log --oneline -5` to match the repo's commit message style.
3. Analyze the changes:
   - Summarize the nature of the change (new feature, bug fix, refactor, docs, etc.)
   - Draft a concise commit message focused on the "why" not the "what"
   - Do NOT commit files that likely contain secrets (.env, .screeps.json, credentials, tokens)
   - Warn the user if any sensitive files are staged
4. Stage specific changed files by name (avoid `git add -A` or `git add .` unless all changes are clearly safe).
5. Commit using a HEREDOC to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
<message here>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

6. Run `git status` to confirm the commit succeeded.
7. Report: what was committed, the commit hash, and the message used.

## Rules

- Never use `--no-verify` unless the user explicitly asks
- Never amend a previous commit unless the user explicitly asks
- If there are no changes to commit, say so — do not create an empty commit
- If a pre-commit hook fails, fix the underlying issue and create a NEW commit (never --amend after a hook failure)
