---
name: commit
description: Use this skill when the user wants to "commit", "commit my changes", "save a checkpoint", "commit this", "make a commit", or "checkpoint my work". It shows what will be committed, drafts a conventional commit message for confirmation, stages specific files, and creates the commit with a Co-Authored-By trailer.
version: 0.1.0
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

Follow this repo's **conventional commit** format exactly:

```
type(scope): short description in sentence case
```

**Types:** `feat`, `fix`, `refactor`, `chore`, `docs`, `style`, `test`, `perf`

**Scope:** use the affected area of the repo — e.g. `gaming`, `laptop`, `security`, `skills`, `vpn`, `memory`, `flake`, `shell`, `users`. Use the most specific scope that fits. If multiple unrelated scopes are touched, pick the dominant one or use no scope.

**Examples from this repo's history:**
- `feat(skills): add new-module skill for NixOS module scaffolding`
- `fix(natalie-laptop): add wg0 DNS for full-tunnel VPN routing`
- `chore(session): end-of-day close 2026-05-18 — WireGuard VPN fully deployed`
- `refactor(vpn): move DNS into shared vpn.nix, apply to all client hosts`
- `chore(memory): update vpn-setup memory with natalie-laptop peer status`

Rules:
- Subject line is lowercase after the colon, no trailing period.
- Keep it under 72 characters.
- Focus on *what changed and why*, not *how*.
- If the change is a session close, use `chore(session): end-of-day close YYYY-MM-DD — <brief summary>`.

Present the drafted message to the user and ask them to **confirm or edit** it before proceeding. Do not commit until the user approves the message.

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

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

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
