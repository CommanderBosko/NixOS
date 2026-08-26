---
name: repo-creator
description: Create and initialize a brand-new GitHub repo (public or private) under CommanderBosko from the current project, then push the first commit. Use when the user says "create a repo", "set up a github repo", "create a private repo", "publish this to github", "initialize a new repo", "set this project up on github", or "make a new repo for this". One-time, at project inception only.
---

# Repo Creator

Create, configure, and push a brand-new GitHub repository for `CommanderBosko` over SSH
— exactly once per project, at inception. Do it right the first time, leave a clean
history, hand off a fully initialized repo.

## Identity & scope

- GitHub account: `CommanderBosko`
- Auth: SSH — remotes use `git@github.com:CommanderBosko/<repo-name>.git`
- Visibility: **public** or **private** — resolved per invocation, see Arguments
- Default branch: `main`
- This is a one-time setup. Once the first push succeeds, the job is done — no further
  commits.

## Arguments

Optional: `public` or `private` (case-insensitive), naming the new repo's visibility.

- If given, use it directly — no need to ask.
- If omitted, ask via **AskUserQuestion** (options **Public** / **Private**, no default
  recommendation — it depends entirely on the project) before Step 6. Visibility is a
  one-time, consequential call made at project inception; don't default it silently.

The repo name is inferred from the current working directory (Step 1), confirmed with the
user only if the directory name is ambiguous.

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
The init/checkout, repo creation, and final stage-commit-push are all mechanical (fixed
commands, no judgment) so they're handled by `scripts/create-repo.sh`; only the
history-pause decision and the commit-message drafting stay here.

```bash
scripts/create-repo.sh init
```
Initializes git and checks out `main` if this isn't a repo yet; if it already is, ensures
the branch is `main` and prints `existing-commits: <n>`. **If `existing-commits` is
non-zero, pause** — this skill is for new projects; use the AskUserQuestion tool (options
**Push existing history** / **Cancel**) to confirm the user wants to push existing history
to a new remote before continuing.

### 6. Resolve visibility, then create the GitHub repo
Resolve visibility first (see Arguments): use the given `public`/`private` argument, or ask
via AskUserQuestion if none was given.

```bash
scripts/create-repo.sh create <repo-name> <visibility>
```
Runs `gh repo create CommanderBosko/<repo-name> --<visibility> --source=. --remote=origin --push=false`,
then normalizes the remote to SSH format if `gh` left it as HTTPS, and prints `git remote -v`.
If `gh` is unavailable, fall back to the GitHub REST API via `curl`, or guide the user to
create it manually and supply the SSH remote.

### 7. Stage
Review what `git status` would stage. If anything sensitive or unnecessary would be
staged, update `.gitignore` first — staging itself happens as part of step 9's script call.

### 8. Craft the initial commit message
Intelligent and specific — never a bare "Initial commit". Read `assets/commit-template.txt`
and fill in its placeholders (repo-root-relative path is
`dotfiles/bosko/claude/skills/repo-creator/assets/commit-template.txt` — this is a repo-managed
global skill; resolve it from the "Base directory for this skill" path shown at launch if
invoked from `~/.claude`).

End the message body with a `Co-Authored-By:` trailer using whatever model name the harness's own
Bash-tool commit-message instructions specify (e.g. "Claude Sonnet 5") — don't hardcode a specific
model name here, it will drift the next time the underlying model changes.

### 9. Commit & push
Write the crafted message (step 8) to a temp file, then:
```bash
scripts/create-repo.sh push <commit-msg-file>
```
Stages everything (`git add .`), commits with `-F <commit-msg-file>`, and pushes with
`-u origin main`. Never `--force`, never `--no-verify`.

### 10. Verify & report
Confirm the push, output the URL `https://github.com/CommanderBosko/<repo-name>`, and
summarize: repo name + URL, file count + key files, README status (created/enhanced/
existing), `.gitignore` status, and the commit message used.

## Error handling

- **SSH key not configured** — guide the user to add their key to GitHub, then retry.
- **Repo name already exists** — use the AskUserQuestion tool (options **Use a different
  name** / **Connect to the existing repo**) to confirm before continuing.
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
- [ ] Repo visibility matches what was chosen (public or private)

## Constraints

- Never push to an existing repo with history without explicit confirmation.
- Never commit `.env`, private keys, or credential files.
- Always SSH, never HTTPS remotes.
- The job ends after a successful push — do not make further commits.

## Assets

- `assets/commit-template.txt` — the initial-commit-message skeleton with its placeholder
  bullets. Read and fill it in Step 8.

## Memory

This skill runs in the main conversation, which already has the project memory system.
If you learn something durable about how the user sets up new projects (preferred license,
default stack choices, naming conventions), save it through the normal memory workflow.
Don't save ephemeral per-repo details — `git log` is authoritative for those.
