---
name: new-skill
description: Create a new Claude Code skill file interactively. Use when the user says "create a skill", "new skill", "add a skill", "make a skill", "build a skill", or "I want a skill that does X".
---

# New Skill Creator

Guide the user through creating a well-formed Claude Code skill, then write the file.

## Steps

### 1. Gather requirements

Ask the user the following — you can ask them all at once in a numbered list:

1. **What should this skill do?** (One sentence goal — what problem does it solve?)
2. **What would you say to invoke it?** (Give 3–5 example phrases — e.g. "run tests", "check for errors", "deploy to staging")
3. **Scope — global or project-local?**
   - Global (`~/.claude/skills/`) — available in every project
   - Project-local (`.claude/skills/` in the current working directory) — only this project
4. **What are the steps?** (Describe the workflow in plain English — tools to run, files to read, decisions to make, output to show)

If the user already gave some of this information in their request, don't re-ask for it — pre-fill it and confirm.

### 2. Derive the skill name

From the goal and trigger phrases, derive a short kebab-case name (e.g. `run-tests`, `deploy-staging`, `check-coverage`). Confirm with the user if it's not obvious.

### 3. Draft the SKILL.md

Build the file content using this template:

```
---
name: <kebab-case-name>
description: <one-sentence description>. Use when the user says "<phrase 1>", "<phrase 2>", "<phrase 3>".
---

# <Title Case Name>

<One sentence summary of what the skill does.>

## Steps

<Numbered or structured steps based on the user's description. Be specific:>
- Name exact commands to run (with flags)
- Name exact file paths to read or write
- Describe what to look for in output
- Describe what to report back to the user
- Note any confirmation steps or edge cases
```

**Quality rules to apply when drafting:**
- Trigger phrases in `description` must match natural speech — include the obvious variants ("run tests", "test", "execute tests")
- Steps must be actionable with Claude Code's tools (Bash, Read, Edit, Write, WebSearch, etc.)
- Include what to output/report to the user at the end
- If a step is conditional, say so explicitly ("if X, do Y; otherwise do Z")
- Keep steps focused — don't add error handling for things that can't happen

### 4. Show the draft

Present the full draft SKILL.md to the user with a brief explanation of any choices you made. Ask for any changes before writing.

### 5. Write the file

Determine the target path:
- **Global:** `~/.claude/skills/<name>/SKILL.md`
- **Project-local:** `.claude/skills/<name>/SKILL.md` (relative to current working directory)

For project-local, first check if `.claude/skills/` exists; create it if not (via `mkdir -p`).

Write the file. Then run:
```bash
ls -la <target-dir>/
```
to confirm the file exists.

### 6. Update CLAUDE.md (project-local only)

If the skill is project-local and a `CLAUDE.md` exists in the project root, check whether it has a skills or slash-commands section. If it does, add the new skill's name and trigger description. If it doesn't, skip this step — don't add a section unprompted.

### 7. Confirm

Tell the user:
- The skill name and where it was written
- The exact phrase(s) that will invoke it
- Whether they need to reload Claude Code for it to appear (global skills: restart or open new session; project-local: available immediately in this project)
