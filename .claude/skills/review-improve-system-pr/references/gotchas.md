# review-improve-system-pr gotchas

- **`gh pr diff` only accepts one pathspec after `--`.** Hit for real 2026-09-05: running
  `gh pr diff <number> --repo CommanderBosko/NixOS -- file1 file2` to scope Step 2's diff to
  specific changed files failed with `accepts at most 1 arg(s), received 3`. Step 2's plain
  `gh pr diff <number> --repo CommanderBosko/NixOS` (no path filter) already shows the full
  diff — don't add a multi-file pathspec to narrow it.

- **`check-settings-diff.sh` used to pass almost any scoped-looking allow entry.** Reproduced
  2026-10-25: `Bash(rm *)`, `Bash(sudo *)`, `Bash(curl *)`, `Bash(gh pr merge*)`, `Bash( *)`,
  `Bash(/*)` and `mcp__claude_ai_Gmail__send_email` all returned rc=0; only a literal `Bash(*)`
  was blocked. A second-pass denylist now refuses high-power command heads, wildcards over
  `git`/`gh`/`nix`, paths outside the repo / `~/.claude` (and any `..`), interpreters without a
  concrete repo script, credential locations, and MCP tools whose name says they write or send.
  It is still a denylist: a pass is not a safety proof, and a refusal just means "review by hand".
  Known residual gap: a path-scoped entry for a repo script (e.g. `.claude/skills/x/scripts/y.sh*`)
  passes, and the file guardrail lets the same PR edit that script.

- **`find-and-check-pr.sh` used to fail open.** When `gh` errored it still printed
  `GUARDRAIL: OK`, and a failed `gh pr list` read as "no PR". Now any `gh`/`jq` failure exits 3
  with `GUARDRAIL: NOT EVALUATED`; exit 1 only follows a clean, empty `gh pr list`. If you see
  exit 3, fix auth/network (`gh auth status`) and re-run — don't treat it as nothing to review.

- **Merge is pinned and CI-gated.** `gh pr merge` alone merges a red PR and whatever commit is
  the head at that moment. Step 4 waits on `gh pr checks --watch` and passes
  `--match-head-commit <PR_HEAD_SHA>` (the SHA the guardrail script printed).
