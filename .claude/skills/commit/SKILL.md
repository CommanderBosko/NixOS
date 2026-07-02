---
name: commit
description: Use this skill when the user wants to "commit", "commit my changes", "save a checkpoint", "commit this", "make a commit", or "checkpoint my work". It shows what will be committed, drafts a conventional commit message for confirmation, stages specific files, and creates the commit with a Co-Authored-By trailer.
version: 0.2.0
---

# Git Commit Workflow

Stage and commit changes in `/home/bosko/NixOS` following this repo's conventional commit style. Never skip hooks. Never amend unless the user explicitly asks.

## Step 1 — Inspect the working tree

Run both commands in parallel:

```bash
git -C /home/bosko/NixOS status
git -C /home/bosko/NixOS diff
```

Present the output to the user in a compact form:
- List **modified/added/deleted files** by name (not the full diff unless there are fewer than 5 changed lines total).
- Note any untracked files that look relevant to the session's work.

## Step 2 — Draft a commit message

Follow this repo's **conventional commit** format exactly. Read `assets/commit-format.md` for the full reference — the `type(scope): short description` shape, the allowed type list, the scope guidance, repo-history examples, and the formatting rules — and draft the message accordingly.

Show the drafted message, then **proceed straight to staging and committing** — do not pause for a
"confirm or edit?" approval step. This matches the user's standing preference: draft and commit
immediately without asking for sign-off. (The only exception is if the user explicitly asked to
review the message first.)

## Step 3 — Stage files

Prefer staging **specific files by path** rather than `git add -A` or `git add .`. Determine which files are relevant to the commit based on the diff output from Step 1.

Only use `git add -A` if the user explicitly requests it or if all untracked/modified files clearly belong to the same commit.

Do not stage files that look like secrets (`.env`, credential files, private keys).

```bash
git -C /home/bosko/NixOS add <path1> <path2> ...
```

## Step 4 — Commit

Use a HEREDOC to pass the message so formatting is preserved:

```bash
git -C /home/bosko/NixOS commit -m "$(cat <<'EOF'
type(scope): short description

Co-Authored-By: <current model> <noreply@anthropic.com>
EOF
)"
```

Use whatever model name the harness's own Bash-tool commit-message instructions specify for
`Co-Authored-By` (e.g. "Claude Sonnet 5") — don't hardcode a specific model name here, it will
drift the next time the underlying model changes.

- Never use `--no-verify`.
- Never use `--amend` unless the user explicitly asked to amend.
- If a pre-commit hook fails, fix the underlying issue and create a **new** commit — do not retry with `--amend`.

## Step 5 — Confirm

Run `git -C /home/bosko/NixOS log --oneline -3` and show the user the new commit hash and message so they can confirm it landed correctly.

---

## Key constraints

- This repo's working directory is always `/home/bosko/NixOS` — always pass `-C /home/bosko/NixOS` to every git command.
- The `Co-Authored-By` trailer is mandatory on every commit made by this skill.
- Do not push — pushing is a separate skill (`push`).

## Assets

- `assets/commit-format.md` — conventional-commit reference (type list, scope guidance, repo-history examples, formatting rules). Read it when drafting the message in Step 2.
