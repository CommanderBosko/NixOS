---
name: repo-creator
description: Create and initialize a brand-new public GitHub repo under CommanderBosko from the current project, then push the first commit. Use when the user says "create a repo", "set up a github repo", "publish this to github", "initialize a new repo", "set this project up on github", or "make a new repo for this". One-time, at project inception only.
---

# Repo Creator

Create, configure, and push a brand-new **public** GitHub repository for `CommanderBosko`
over SSH — exactly once per project, at inception. Do it right the first time, leave a
clean history, hand off a fully initialized repo.

## Identity & scope

- GitHub account: `CommanderBosko`
- Auth: SSH — remotes use `git@github.com:CommanderBosko/<repo-name>.git`
- Visibility: **public**
- Default branch: `main`
- This is a one-time setup. Once the first push succeeds, the job is done — no further
  commits.

## Workflow

### 1. Determine the repo name
Use the **exact name of the current working directory** (e.g. `/home/bosko/pixel-engine`
→ `pixel-engine`). Confirm with the user if the directory name is ambiguous.

### 2. Inspect the project
- List the project root.
- Identify language/framework/purpose from existing files (`package.json`, `flake.nix`,
  `Cargo.toml`, `pyproject.toml`, etc.).
- Decide what to include/exclude.

### 3. Create or improve `README.md`
If none exists, create a substantive one: project name as H1, accurate description, tech
stack/dependencies, setup/install steps (based on what you find), usage examples if
applicable, and a License section (default MIT unless the project says otherwise). If one
exists, enhance it only where it's sparse.

### 4. Create `.gitignore` (if missing/incomplete)
Tailor to the detected stack. Always exclude `.env`, `*.log`, build artifacts, and IDE
files (`.idea/`, `.vscode/` unless intentionally used). For Nix projects exclude
`.direnv/`, `result`, `result-*`.

### 5. Initialize git (if needed)
```bash
git init
git checkout -b main
```
If already a repo, ensure the default branch is `main`. **If the directory already has
real git history, pause** — this skill is for new projects; confirm the user wants to push
existing history to a new remote before continuing.

### 6. Create the GitHub repo
```bash
gh repo create CommanderBosko/<repo-name> --public --source=. --remote=origin --push=false
```
If `gh` is unavailable, fall back to the GitHub REST API via `curl`, or guide the user to
create it manually and supply the SSH remote. Then verify and force SSH format:
```bash
git remote -v
git remote set-url origin git@github.com:CommanderBosko/<repo-name>.git  # if HTTPS
```

### 7. Stage
```bash
git add .
```
Review staged files. If anything sensitive or unnecessary is staged, unstage it and update
`.gitignore` first.

### 8. Craft the initial commit message
Intelligent and specific — never a bare "Initial commit". Structure:
```
Initial commit: <one-line project summary>

- <primary purpose or feature>
- <major components / structure>
- <tech stack / key dependencies>
- <configuration or setup included>
- Add README.md with setup and usage documentation
- Add .gitignore for <tech stack>
```
End the message body with:
`Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

### 9. Commit & push
```bash
git commit -m "<crafted message>"
git push -u origin main
```
Never `--force`, never `--no-verify`.

### 10. Verify & report
Confirm the push, output the URL `https://github.com/CommanderBosko/<repo-name>`, and
summarize: repo name + URL, file count + key files, README status (created/enhanced/
existing), `.gitignore` status, and the commit message used.

## Error handling

- **SSH key not configured** — guide the user to add their key to GitHub, then retry.
- **Repo name already exists** — ask whether to use a different name or connect to the
  existing repo.
- **`gh` not installed** — fall back to `curl` GitHub API, or give manual instructions.
- **Sensitive untracked files** — warn, add to `.gitignore`, do not commit them.
- **Existing git history** — pause and confirm (see Step 5).

## Quality checklist (before pushing)

- [ ] Remote URL is SSH (`git@github.com:CommanderBosko/...`)
- [ ] Branch is `main`
- [ ] `README.md` exists and is substantive
- [ ] `.gitignore` exists and fits the stack
- [ ] No secrets staged (tokens, passwords, `.env`)
- [ ] Commit message is descriptive and project-specific
- [ ] Repo visibility is public

## Constraints

- Never push to an existing repo with history without explicit confirmation.
- Never commit `.env`, private keys, or credential files.
- Always SSH, never HTTPS remotes.
- The job ends after a successful push — do not make further commits.

## Memory

This skill runs in the main conversation, which already has the project memory system.
If you learn something durable about how the user sets up new projects (preferred license,
default stack choices, naming conventions), save it through the normal memory workflow.
Don't save ephemeral per-repo details — `git log` is authoritative for those.
