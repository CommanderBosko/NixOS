---
name: new-skill
description: Create a new Claude Code skill file interactively. Use when the user says "create a skill", "new skill", "add a skill", "make a skill", "build a skill", or "I want a skill that does X".
---

# New Skill Creator

Guide the user through creating a well-formed Claude Code skill, then write the file.

## Arguments

Parse from the user's invocation phrase, if given:

- **goal** — a one-sentence description of what the skill should do, if stated in the request (e.g. "create a skill that tails logs for a service").
- **name** — a proposed kebab-case skill name, if the user names it directly.
- **steps** — any workflow detail the user already volunteers (tools to run, files to read, decisions to make).
- **scope** — `global` or `project-local`, if stated (see step 1).

Pre-fill step 1's questions and step 3's name derivation from whatever is already given, and confirm rather than re-asking. Only ask for what's still missing.

## Steps

### 1. Gather requirements

Ask the user the following free-form questions — you can ask them all at once in a numbered list:

1. **What should this skill do?** (One sentence goal — what problem does it solve?)
2. **What would you say to invoke it?** (Give 3–5 example phrases — e.g. "run tests", "check for errors", "deploy to staging")
3. **What are the steps?** (Describe the workflow in plain English — tools to run, files to read, decisions to make, output to show)

If the user already gave some of this information in their request, don't re-ask for it — pre-fill it and confirm.

Separately, resolve **scope** — this is a genuine pick-one, not a free-form question, so present it via
the **AskUserQuestion tool** rather than folding it into the numbered list above. Skip the question
if the user already stated the scope in their request.

- **Global** — available in every project. In this NixOS repo, global skills are **repo-managed**: the source lives in `dotfiles/bosko/claude/skills/` and is symlinked into `~/.claude/skills/` via `bosko-claude.nix` (Home Manager). See step 6 for the wiring this requires.
- **Project-local** (`.claude/skills/` in the current working directory) — only this project.

### 2. Classify into exactly one bucket (single-responsibility gate)

Every skill must fit cleanly into **one** of these four buckets. The best skills do exactly one job; a skill that straddles two buckets confuses the agent about when to reach for it.

1. **Utility** — one small reusable thing, every time (e.g. format files, stage a commit, tail a log).
2. **Verification** — checks the quality of a final output (e.g. dry-run gate, health sweep, secret scan).
3. **Data Enrichment** — pulls **external** data in (e.g. look up a package, bump an input to its latest upstream revision).
4. **Orchestration** — chains other skills into a multi-step playbook (e.g. update → verify → commit → push).

State which bucket this skill lands in and confirm it with the user. Then apply the gate:

- **If it spans 2+ buckets, stop and split it** (or trim its scope) before drafting. Two independent jobs = two skills.
- **Exception:** an Orchestration skill that *coordinates* other skills is not straddling — chaining a Utility + a Verification step is exactly its job. The straddle test is whether the skill does two **independent** jobs that could each stand alone, not whether it calls more than one tool.
- A red flag for a hidden straddle: the description contains "save X **then** synthesize Y" or "do A **and also** B" where A and B don't depend on each other.

Record the chosen bucket — it goes in the draft (see step 4).

### 2a. Pick a model tier

Classify the skill's dominant work as one of:

- **grunt** — mechanical: run a fixed command and relay/format the output, fetch data, classify by fixed criteria, template-fill. Pin `model: haiku` in the frontmatter to cut cost/latency.
- **judgment** — synthesis, auditing for subtle issues, planning/architecture, drafting non-trivial content from scratch, or deciding an action with real consequences (data loss, security, irreversible changes). Omit `model:` so it inherits the session's top model.

If genuinely mixed, default to omitting `model:` — judgment work is the more expensive failure mode to get wrong. Record the tier — it goes in the draft (see step 4).

### 2b. Identify deterministic chunks to extract to `scripts/`

Look at each step gathered in Step 1. If a step is a fixed, judgment-free command sequence — a specific command/flag combo, a parse, a per-host loop, a lookup — that would otherwise get re-improvised in prose every run, plan to extract it into `scripts/<name>.sh` rather than inlining it. The SKILL.md prose then calls the script and keeps only the interpretation/judgment/branching logic (what the output means, what to do next).

Before writing a new script, check whether an existing one already does this: project-local skills share common lookups via `.claude/lib/` (e.g. `resolve-host.sh`, `list-flake-inputs.sh`) — reuse or extend one of those instead of duplicating. Don't force a script onto a step that's already a single trivial one-liner, or one that inherently requires judgment about the specific case (those stay as prose).

Record which steps (if any) get a script, and its intended name and contract (arguments in, what it prints, exit code meaning) — it goes in the draft (see step 4) and the write (see step 6).

### 3. Derive the skill name

From the goal and trigger phrases, derive a short kebab-case name (e.g. `run-tests`, `deploy-staging`, `check-coverage`). Confirm with the user if it's not obvious.

### 4. Draft the SKILL.md

Read the scaffold from `assets/skill-template.md` (relative to this skill's directory) and build the file content by filling its `<…>` placeholders from the interview — the goal, name, trigger phrases, bucket, and steps. The template content is the fenced block in that asset (don't include the surrounding code fence in the final file).

**Quality rules to apply when drafting:**
- The skill must do exactly one job in its single bucket (step 2) — if drafting surfaces a second independent job, stop and split
- If step 2a classified this as **grunt**, add a `model: haiku` line directly after `description:` in the frontmatter (matching the convention used by other grunt-work skills in this repo). If **judgment**, omit the field entirely — don't write `model: sonnet` or similar, since that would pin it and stop it from tracking the session's top model over time.
- For every chunk step 2b flagged, write the deterministic logic into `scripts/<name>.sh` (a real file, written in step 6) and have the corresponding SKILL.md step call it and interpret its output — don't inline the bash/jq/loop in prose. If the skill ends up with one or more scripts, add a `## Scripts` section near the end of the file (mirror `add-secret/SKILL.md`'s format: one bullet per script, its path, its arguments, and which step calls it).
- Trigger phrases in `description` must match natural speech — include the obvious variants ("run tests", "test", "execute tests")
- Steps must be actionable with Claude Code's tools (Bash, Read, Edit, Write, WebSearch, etc.)
- Include what to output/report to the user at the end
- If a step is conditional, say so explicitly ("if X, do Y; otherwise do Z")
- Keep steps focused — don't add error handling for things that can't happen

### 5. Show the draft

Present the full draft SKILL.md to the user with a brief explanation of any choices you made. Ask for any changes before writing.

### 6. Write the file

Determine the target path by scope:

- **Global, in a Home-Manager-managed repo** (the common case here). Detect it: you're in the NixOS config repo if `dotfiles/bosko/bosko-claude.nix` and `dotfiles/bosko/claude/skills/` both exist (equivalently, `~/.claude/skills/*/SKILL.md` resolve into `/nix/store` — they're read-only symlinks). When managed, **do NOT write to `~/.claude/skills/`** — that path is read-only and an untracked file there is wiped on the next rebuild. Instead:
  1. Write the SKILL.md (and, if step 2b flagged any, `scripts/<name>.sh`) to `dotfiles/bosko/claude/skills/<name>/`.
  2. Add a `home.file` entry to `dotfiles/bosko/bosko-claude.nix`. If the skill has (or is likely to grow) `scripts/`/`assets/` files, prefer a **recursive** directory entry from the start — mirroring the several existing global skills already using `recursive = true` (grep `bosko-claude.nix` for the pattern) — so a script added later needs no further wiring:
     ```nix
     ".claude/skills/<name>" = {
       source = "${self}/dotfiles/bosko/claude/skills/<name>";
       recursive = true;
     };
     ```
     Otherwise (a plain single-file skill, no `scripts/`/`assets/`), use the simpler file-by-file form:
     ```nix
     ".claude/skills/<name>/SKILL.md" = {
       source = "${self}/dotfiles/bosko/claude/skills/<name>/SKILL.md";
       force = true;
     };
     ```
  3. `git add dotfiles/bosko/claude/skills/<name>/ dotfiles/bosko/bosko-claude.nix` — flake evaluation only sees tracked files, so the new file(s) must be staged before a dry-run/rebuild.
  4. Optionally run `nh os boot /home/bosko/NixOS --dry` (or the `nixos-dry-run` skill) to confirm the config still evaluates. The `~/.claude/skills/<name>/` symlink appears only **after** a real rebuild (`nh os boot /home/bosko/NixOS`).
- **Global, plain `~/.claude`** (no Home Manager managing it): write directly to `~/.claude/skills/<name>/SKILL.md`.
- **Project-local:** `.claude/skills/<name>/SKILL.md` (relative to the current working directory). First check if `.claude/skills/` exists; create it if not (via `mkdir -p`). Auto-discovered immediately — no rebuild.

Write the file. If step 2b identified any script extractions, also write `<target-dir>/scripts/<name>.sh`, `chmod +x` it, and run `bash -n` on it to confirm it's syntactically valid before moving on.

Then run `ls -la <target-dir>/` (and `<target-dir>/scripts/` if applicable) to confirm everything exists. For the managed-global case, also confirm the `bosko-claude.nix` entry is in place.

### 7. Update CLAUDE.md (project-local only)

If the skill is project-local and a `CLAUDE.md` exists in the project root, check whether it has a skills or slash-commands section. If it does, add the new skill's name and trigger description. If it doesn't, skip this step — don't add a section unprompted.

### 8. Confirm

Tell the user:
- The skill name and where it was written
- Any `scripts/<name>.sh` files written alongside it, and confirm they passed `bash -n`
- The exact phrase(s) that will invoke it
- How it becomes available:
  - **Managed-global** (repo `dotfiles/` + `bosko-claude.nix`): it appears in `~/.claude/skills/` only after `nh os boot /home/bosko/NixOS` **+ reboot**. The repo copy works in the meantime when invoked from the repo.
  - **Plain global** (`~/.claude`): restart or open a new session.
  - **Project-local:** available immediately in this project.
- **This skill hasn't been smoke-tested.** `new-skill` only drafts and writes the file — it doesn't verify the skill actually works. Point the user at `ship-skill` (which chains draft → smoke-test → commit → push) for a tested result, or offer to test it inline now if the user wants to stay in `new-skill`.

## Gotchas

- **The `nixos-dry-run` parenthetical in step 6 only works when the session's cwd is `~/NixOS`** — it's a project-local skill there, not global, so invoking it from another project fails with `Unknown skill: nixos-dry-run`. Prefer the direct `nh os boot /home/bosko/NixOS --dry` command listed first when working from outside `~/NixOS`.

## Assets

- `assets/skill-template.md` — the SKILL.md scaffold. Read it in step 4 and fill its `<…>` placeholders (name, description/trigger phrases, bucket, steps) to draft the new skill. Drop the surrounding code fence from the final written file.
