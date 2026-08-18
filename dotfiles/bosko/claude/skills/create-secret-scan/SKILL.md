---
name: create-secret-scan
description: Generate a project-local secret-scan skill tuned to the current project's secret-handling conventions. Use when the user says "create a secret scan", "/create-secret-scan", "set up secret scanning here", "make a secret-scan skill for this project", or when session-closer finds no project-local secret-scan skill and the user agrees to create one.
---

# Create Secret Scan — Secret-Scan Generator

Interview the user, then generate a **project-local secret-scan skill**
(`.claude/skills/secret-scan/SKILL.md` + `scripts/secret-scan.sh`) tuned to how *this*
project actually manages secrets. Every project's needs a scan, but no two projects
manage secrets the same way — one repo git-ignores a `.env`, another encrypts a
`secrets/` directory with sops, another uses git-crypt or a cloud secrets manager. A
one-size-fits-all global scanner either misses a project's real secret format or cries
wolf on things that are intentionally public (endpoint IPs, public keys).

This is a *meta-skill*: it writes another skill. It does **not** run the scan itself —
it produces the project-local skill and verifies that skill is well-formed.

## Arguments

Parse from the user's invocation phrase, if given:

- **Secret-management scheme** — if the user already names it (e.g. "we use sops",
  "it's just a gitignored .env"), that answers interview question 1 directly.
- **Paths to exclude** — any directories/globs already volunteered (e.g. "skip the
  fixtures dir").
- **Full git-history scan** — if the user states a preference up front (e.g. "don't
  bother scanning history, this repo is huge").

Pre-fill Step 1's interview questions from whatever is already given, and confirm rather
than re-asking. Still run the detection hints and ask for whatever's missing — this
doesn't replace the interview, it just skips re-asking what's already stated.

## Key facts (don't re-derive these)

- **Generated skills are project-local:** `<repo-root>/.claude/skills/secret-scan/`.
  Immediately runnable as `/secret-scan`, no rebuild, committed with the project.
- **`/create-secret-scan` itself is global/repo-owned** (lives under
  `dotfiles/bosko/claude/skills/create-secret-scan/`, symlinked via `bosko-claude.nix`).
  You are using that copy now; do not touch the read-only `~/.claude` symlink.
- **The baseline high-signal pattern library is already baked into the template** —
  private-key blocks, AWS/GitHub/Slack tokens, unix password hashes. You don't need to
  re-derive these; the interview only tunes what's *project-specific* on top of them.
- **`model: haiku` is pinned in every generated skill** — running a pattern scan and
  reporting findings is grunt work, not judgment.

## Steps

### 1. Interview for the project's secret-handling conventions

Ask these together as a numbered list. Where you can infer an answer from the repo
itself (see the detection hints), propose it and ask the user to confirm rather than
asking blind.

1. **Secret-management scheme** — how does this project handle secrets today? Common
   answers: no scheme / plain env vars, a gitignored `.env` file, an encrypted directory
   (sops, git-crypt, transcrypt, blackbox), a cloud/vault secrets manager (referenced by
   ID, not stored in-repo), or "not sure." Detection hints: grep for `sops:` / `ENC[` in
   tracked files, check `.gitignore` for `.env`/`*.age`/`*.key`, look for a `secrets/` or
   `vault/` directory, check for `.git-crypt/` or `.sops.yaml`.
2. **Encrypted/managed secret location** — if there's a dedicated directory or glob
   (e.g. `secrets/*.yaml`), what marks a file inside it as *properly* encrypted (e.g.
   sops files contain `ENC[` and a `sops:` block; git-crypt files are binary-looking in
   the working tree but that's enforced by git attributes, not grep — for git-crypt,
   there is usually nothing meaningful to grep-check, so skip pass 2 for it)? If there's
   no such scheme, say so — pass 2 becomes a no-op.
3. **Paths to exclude from pattern matching** — besides the generated skill's own
   directory (always excluded, its docs contain example patterns), are there other
   paths that would false-positive: fixtures/test data with fake credentials, vendored
   third-party code, generated files?
4. **Known intentional non-secrets** — anything that looks secret-shaped but is
   deliberately public (a real IP, a public key, a demo token in docs)? These aren't
   filtered programmatically (the baseline patterns are already tight enough to avoid
   them) — just document them in the generated skill's notes so a human/Claude doesn't
   flag them anyway.
5. **Extra project-specific patterns** — any secret formats beyond the generic baseline
   worth adding (Stripe keys, an internal API token format, a JWT signing key literal)?
   Optional — leave empty if the baseline covers it.
6. **Full git-history scan** — scan every commit (catches secrets committed then
   removed)? Default **yes**; only say no for a very large/old repo where it'd be too
   slow to be useful in practice.
7. **.gitignore coverage to check** — which extensions/globs should be gitignored for
   this project's scheme (e.g. `.env`, `*.pem`, `*.key`, plus `*.age` for
   sops/age-based schemes)? Propose a sensible default from the scheme answer.

If the user doesn't know the scheme, that's a valid answer — generate the skill with
"no dedicated scheme" and encourage them to at least gitignore common secret-file
patterns; a generic scan is still far better than none.

### 2. Fill the generated skill from the templates

Two assets define the generated skill; read both, fill every `<…>` placeholder from the
interview, and write the results:

1. **`assets/secret-scan-template.md`** (relative to this skill's directory) — the
   contract for `<repo-root>/.claude/skills/secret-scan/SKILL.md`. Content lives between
   the `<!-- BEGIN -->` / `<!-- END -->` markers (exclude the markers themselves).
   Placeholders: `<SCHEME_LABEL>` (short label, e.g. "sops-encrypted `secrets/`"),
   `<SCHEME_DESCRIPTION>`, `<ENCRYPTED_LOCATIONS_NOTE>`, `<EXCLUDED_PATHS_NOTE>`,
   `<KNOWN_NON_SECRETS_NOTE>`, `<HISTORY_SCAN_NOTE>`, `<EXTRA_PATTERNS_NOTE>` (a short
   parenthetical addition to the working-tree bullet, or empty), `<ENCRYPTED_INTEGRITY_INSTRUCTION>`,
   `<HISTORY_SCAN_INSTRUCTION>`, `<REMEDIATION_PLAINTEXT>`, `<REMEDIATION_UNENCRYPTED>`.
   If a placeholder doesn't apply (e.g. no encryption scheme), fill it with a plain
   statement of that fact rather than leaving it blank — the lint step rejects leftover
   `<…>` tokens either way, so every placeholder must be replaced with real text.
2. **`assets/secret-scan-script-template.sh`** (relative to this skill's directory) —
   the entire file **is** the script template (no markers needed, it's already valid
   bash apart from the placeholders). Placeholders: `<EXCLUDE_PATHSPECS>` (bash array
   elements, always include `':!.claude/skills/'` plus the project's own excludes, git
   pathspec syntax like `':!secrets/'`), `<ENCRYPTED_GLOB>` / `<ENCRYPTED_MARKERS>`
   (empty strings if no scheme), `<SCAN_HISTORY>` ("yes"/"no"), `<EXTRA_PATTERNS>` (bash
   array elements, `"description::ERE-pattern"` format, empty if none), and
   `<GITIGNORE_PATTERNS>` (bash array elements, quoted globs).

Write the filled SKILL.md to `<repo-root>/.claude/skills/secret-scan/SKILL.md` and the
filled script to `<repo-root>/.claude/skills/secret-scan/scripts/secret-scan.sh`, then
`chmod +x` the script. Create the directories with `mkdir -p` if they don't exist.

### 3. Verify the generated skill (built-in verification plan)

1. **Structural lint (mechanical, scripted)** — run (absolute path — a bare `scripts/...`
   path 404s, this is a global home-symlinked skill and the Bash tool's cwd is the project
   root, not this skill's directory):
   ```bash
   /home/bosko/.claude/skills/create-secret-scan/scripts/lint-secret-scan.sh <repo-root>/.claude/skills/secret-scan
   ```
   It checks presence/shape only (never meaning): frontmatter `name:`/`description:`,
   `name:` matching the directory name, `model: haiku` pinned, required sections, no
   leftover `<PLACEHOLDER>` tokens in either generated file, the script exists,
   is executable, and is syntactically valid bash. Fix anything it FAILs before
   continuing.
2. **Live dry run (judgment, not scriptable)** — actually run the generated
   `scripts/secret-scan.sh` once against the real repo. Confirm it executes cleanly
   (no bash errors) and that its pass-2/pass-3 skip messages match what the interview
   said (e.g. if the user said "no encryption scheme," pass 2 should print the skip
   line, not silently do nothing wrong).

### 4. Offer to commit

After verification passes, use the **AskUserQuestion** tool to offer committing the new
skill (`.claude/skills/secret-scan/`), with options **Commit now** (draft a conventional
commit message and commit immediately, no line-by-line approval) and **Skip for now**
(leave it uncommitted).

### 5. Confirm and hand off

Tell the user:
- The full path written and that it's runnable immediately via `/secret-scan` in this
  project (project-local, no rebuild).
- A one-line summary of what it's tuned for (scheme, exclusions, history-scan setting).
- That `session-closer`'s public-safety pass will now find and use it automatically.

## Gotchas

- **Project-local skills resolve immediately** — no rebuild needed for the *generated*
  skill. Only `/create-secret-scan` itself (being global/repo-owned) needs a rebuild to
  update.
- **`name:` must equal the directory name**, or `/secret-scan` won't resolve in that
  project.
- **Every placeholder must be filled with something**, even "N/A — no scheme
  configured." The lint step fails on any leftover `<…>` token, and a half-filled
  template is worse than an honest "not applicable" note.
- **Don't invent a scheme the project doesn't have.** If the user says "no dedicated
  secret-management scheme," leave `<ENCRYPTED_GLOB>` and `<ENCRYPTED_MARKERS>` empty
  rather than guessing sops just because that's what the reference example (this repo's
  own NixOS `secret-scan`) uses — that skill is one example of a tuned scan, not the
  default for every project.

## Scripts

- `/home/bosko/.claude/skills/create-secret-scan/scripts/lint-secret-scan.sh <path-to-skill-dir>` — Step 3's mechanical structural
  checks (frontmatter, name/directory match, model pin, required sections, no leftover
  placeholders, script present/executable/valid).

## Assets

- `assets/secret-scan-template.md` — the verbatim contract for the generated project's
  `SKILL.md` (the content between its `<!-- BEGIN -->` / `<!-- END -->` markers). Read
  it, fill its `<…>` placeholders from the interview, write the result to
  `<repo-root>/.claude/skills/secret-scan/SKILL.md`.
- `assets/secret-scan-script-template.sh` — the verbatim contract for the generated
  project's `scripts/secret-scan.sh` (the whole file is the template, no markers). Read
  it, fill its `<…>` placeholders from the interview, write the result to
  `<repo-root>/.claude/skills/secret-scan/scripts/secret-scan.sh`, and `chmod +x` it.
