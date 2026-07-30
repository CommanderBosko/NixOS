---
name: skill-audit
description: Audit every skill in the project against a structured quality rubric — single-bucket fit, deterministic-work-to-scripts, templates-to-assets, re-entered-config, AskUserQuestion, and invocation arguments — then produce one prioritized report. Use when the user says "skill-audit", "audit my skills", "audit every skill", "review all my skills", or "check my skills for improvements".
---

# Skill Audit

Sweep **every** skill in the project and evaluate each against a fixed quality rubric, then produce a single prioritized report: real bugs first, then the highest-leverage structural improvements. Like `audit-config`, this skill **audits and reports** — it does not auto-apply changes. If the user then says "fix it", implement in priority order (see the last section).

(Bucket: Verification — its one output is a quality report on the skill library. It fans work out to sub-agents to read in parallel, but that is an implementation detail, not skill-chaining.)

## Step 0 — Check logs since the last audit

**Always check what's happened since skill-audit itself last ran**, so the sweep can flag skills that are new or changed since the last pass, and any misfires logged in the meantime. Get the cutoff first:

```bash
~/.claude/skills/lib/find-last-skill-invocation.sh skill-audit
```

This prints the ISO-8601 timestamp of skill-audit's previous invocation for this project, or nothing if it's never run before. Then resolve which transcripts are new since then:

```bash
~/.claude/skills/lib/list-transcripts-since.sh "<cutoff-from-above>"
```

An empty cutoff (first-ever run) lists the full transcript history instead. Skim the listed transcripts (never read them whole — `grep` for `Write`/`Edit` calls touching `SKILL.md` paths, and for `is_error` tool results with a `Skill` active) to note: skills created or materially edited since the last audit (give these closer scrutiny — they haven't been swept yet), and any recurring misfires logged since then (feed these into the correctness-bugs section of Step 3, don't leave them to `skill-upgrade` alone). This is a scoping aid, not a replacement for Steps 1–2's full sweep — every skill still gets audited every time.

## Step 1 — Enumerate every skill

Find all skills and their shape. There are usually two locations:

- **Project-local:** `.claude/skills/<name>/SKILL.md` (auto-discovered; new sibling `scripts/`/`assets/` files just work).
- **Global / repo-owned:** if this repo symlinks skills into `~/.claude` (e.g. via Home Manager `home.file`), the source is under `dotfiles/**/claude/skills/<name>/`. **These are symlinked file-by-file** — adding a `scripts/` or `assets/` file to one needs a new symlink entry **plus a rebuild** before it appears. Treat script/asset extraction for global skills as higher-cost (flag it, but don't assume it's free).

The enumeration itself is mechanical (iterate both locations, print each skill's name, its
`SKILL.md` line count, and any sibling files), so it's handled by the script — run it from
the repo root:

```bash
scripts/enumerate-skills.sh
```

Confirm it exits `0` and prints one line per skill before trusting its output — an empty or
truncated listing means the script broke partway through, not that there are no more skills.

Note which skills already have `scripts/`, `assets/`, or a `config.json` — those lenses are already satisfied there.

## Step 2 — Fan out the audit over DISJOINT skill sets

The skills don't depend on each other, so audit them in parallel. Partition all skills into 3–5 groups and spawn one sub-agent per group **in a single message**. Critical rules:

- **Disjoint partitions** — no two agents own the same skill file. This keeps a later "fix it" pass conflict-free if each agent also owns the edits for its group.
- Give every agent the **identical rubric** (below) and a tight output format: per skill, only the lenses that genuinely apply, each as `Lens N: <finding> → <concrete change>`; one line for clean skills; end with "biggest wins".
- Tell agents this pass is **read-only** — report, don't edit.

### The rubric (apply all to each skill)

1. **Single-bucket fit** — does the skill do exactly one job in one bucket (Utility / Verification / Data Enrichment / Orchestration)? Flag straddlers — two *independent* jobs bundled (tell: "do X **then** Y" where Y doesn't need X). Orchestration that *coordinates other skills* is not straddling. → split or trim.
2. **Deterministic → `scripts/`** — a mechanical, judgment-free chunk (a fixed command sequence, a parse, a per-host loop) re-improvised in prose every run → extract to `scripts/<name>.sh`; keep interpretation in the SKILL.
3. **Templated output → `assets/`** — a large literal template/scaffold/boilerplate inlined in prose → move to `assets/<file>` and read+fill it.
4. **Re-entered config → `config.json`** — a constant or **list** re-typed inline every run (paths, host/target maps, rosters) — especially one that has **drifted** between skills → lift into one shared JSON read at runtime. A single repo-path constant is fine; flag clusters and drift-prone lists.
5. **AskUserQuestion** — a pick-one / multiple-choice prompt (or destructive yes/no gate) asked in free-form prose → present via the AskUserQuestion tool with defined options (preserve "skip if the user already supplied it"). Leave deliberately conversational interviews alone.
6. **Invocation arguments** — inputs the user supplies in their phrasing (slug, file path, target host, package, person). Document them in a `## Arguments` prose section (mirror `verify-service`). ⚠️ Do **not** add an `arguments:` YAML frontmatter key unless its support is confirmed — that's a slash-command feature, not a SKILL.md one.

## Step 3 — Synthesize one prioritized report

Merge the agents' findings into a single report, ordered by leverage, not by skill:

1. **Correctness bugs first.** The audit surfaces real bugs, not just style — usually from inline-duplicated constants that drifted (a wrong host/user, a stale roster, a list naming things that no longer exist). **Verify each empirically before reporting it** (run the command, read the file) — the "documentation" may be the stale copy, not the truth.
2. **Cross-cutting wins** — one shared config that de-dupes N skills; the single biggest template extraction; lists that should be live-derived instead of stored.
3. **Per-lens rollup** — the remaining script/asset/AskUserQuestion/arguments candidates.
4. Name the skills that are already clean (so the user sees the sweep was complete).

**Report every finding that survives verification — across every skill, every lens — not just the single highest-priority one.** A list of one is fine if that's genuinely all the sweep turned up; don't truncate a longer list for brevity. Be blunt; skip clean skills; lead with what matters.

## Step 4 — Report, don't auto-apply

Present the report and stop. Offer to implement, recommending an order (bugs → shared config → big asset/script extractions → UX). Call out anything you'd **skip** as low-value or high-overhead (e.g. global-skill asset extraction needing symlink wiring; speculative frontmatter) and let the user decide.

## If the user says "fix it" — implement in priority order

- Work highest-priority first; **commit at phase boundaries** so each lands cleanly.
- **Verify empirically as you go** — run the scripts you extract (read-only paths), `bash -n` every script, and prove drift fixes against the live system. Don't guess at a value you can test.
- Re-derive drift-prone data **live** rather than re-hardcoding it (enumerate inputs/DE modules from the tree; resolve hosts from the shared config).
- For NixOS repos: after touching anything the flake evaluates (or a symlinked global skill), run a dry-run (`nixos-dry-run`) to certify it still evaluates. Project-local `.claude/` changes don't affect the flake.
- Adding a **new global skill** (or new sibling files for one) requires the Home Manager `home.file` symlink entry + a rebuild before it appears in `~/.claude`.

## Gotchas

- **Don't trust inline tables as ground truth.** Duplicated constants drift; the skill's own documentation can be the stale copy. We once found a skill documenting the wrong SSH user — the "wrong-looking" script was actually right.
- **Disjoint partitions matter.** If two sub-agents edit the same skill, their changes collide. Partition so each skill (and its future edits) has exactly one owner.
- **Global vs project-local is the overhead axis.** Script/asset extraction is free for project-local skills, but costs a symlink entry + rebuild for global ones. Weigh that before recommending it.
- **A clean skill is a result.** Say "clean on all 6" in one line rather than inventing findings.
- **`enumerate-skills.sh` lives in the SKILL's base dir, not the repo** (observed 2026-07-02): invoking `scripts/enumerate-skills.sh` relative to the repo root fails — the repo's `scripts/` is empty. Run `bash <skill-base-dir>/scripts/enumerate-skills.sh` (the base dir is printed when the skill loads), with the repo root as cwd.
