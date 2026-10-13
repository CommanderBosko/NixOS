# Resolving a global skill's own files

Global skills are home-symlinked into `~/.claude/skills/<name>/`. During a run, the Bash
tool's working directory is the **project root**, not the skill's directory. So a bare
`scripts/foo.sh`, `assets/...`, or `references/...` path, or a guessed project-relative
`.claude/skills/<name>/...` path, resolves against the wrong directory and 404s (exit 127).

**Rule:** build every script, asset, or reference path from the "Base directory for this
skill" line shown when the skill launches, for example
`/home/bosko/.claude/skills/git-commit/scripts/git-commit.sh`. Shared helpers in this
directory are at `/home/bosko/.claude/skills/lib/<script>`.

First observed 2026-07-25 (git-push) and 2026-07-27 (git-commit); skill-audit found it again
in repo-creator on 2026-09-06. It came back in many global skills, so each one now points
here instead of keeping its own copy of this gotcha.
