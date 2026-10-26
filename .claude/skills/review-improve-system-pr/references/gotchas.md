# review-improve-system-pr gotchas

- **`gh pr diff` only accepts one pathspec after `--`.** Hit for real 2026-09-05: running
  `gh pr diff <number> --repo CommanderBosko/NixOS -- file1 file2` to scope Step 2's diff to
  specific changed files failed with `accepts at most 1 arg(s), received 3`. Step 2's plain
  `gh pr diff <number> --repo CommanderBosko/NixOS` (no path filter) already shows the full
  diff — don't add a multi-file pathspec to narrow it.

- **`check-settings-diff.sh` used to pass almost any scoped-looking allow entry.** Reproduced
  2026-10-25: `Bash(rm *)`, `Bash(sudo *)`, `Bash(curl *)`, `Bash(gh pr merge*)`, `Bash( *)`,
  `Bash(/*)` and `mcp__claude_ai_Gmail__send_email` all returned rc=0; only a literal `Bash(*)`
  was blocked. A denylist follow-up was bypassed in review (`git --no-pager push*`,
  `python3.13 -c *`, `nix-build *`, double spaces, `cat ~/.docker/config.json`, MCP tools like
  `postmessage`), so the second pass is now default-deny: an added entry passes only if it is an
  exact-shape match for a short read-only allowlist (read-only git/gh/nix/systemctl/flatpak
  subcommands with no global flags, metadata-only inspectors, concrete `.claude/.../scripts/*.sh`
  files, MCP tools starting with a read verb). A pass is not a safety proof, and a refusal just
  means "review by hand" — many harmless commands (`cat`, `grep`, `jq`, `sed -n`) are refused on
  purpose. Residual risk the checker cannot see: a `*` rule matches any arguments at run time
  (`git log *` can be run with `--output=<file>`, `git fetch*` with `--upload-pack`), and a script
  entry runs whatever the script contains (the file guardrail now flags edits to such scripts —
  see "The file guardrail used to wave through ..." below).

- **`find-and-check-pr.sh` used to fail open.** When `gh` errored it still printed
  `GUARDRAIL: OK`, and a failed `gh pr list` read as "no PR". Now any `gh`/`jq` failure exits 3
  with `GUARDRAIL: NOT EVALUATED` (a failed `settings.json` fetch included — it used to read as a
  guardrail violation); exit 1 only follows a clean, empty `gh pr list`. If you see
  exit 3, fix auth/network (`gh auth status`) and re-run — don't treat it as nothing to review.

- **The file guardrail used to wave through edits to scripts that run unprompted, and edits to
  the gate itself.** A post-merge review (verified with a shim PR) got `exit 0` / `GUARDRAIL: OK`
  for a PR that added `.claude/skills/x/scripts/evil.sh` plus `Bash(bash .claude/skills/x/scripts/evil.sh *)`,
  for one editing `secret-scan.sh` and `scan-session.sh` (both behind existing allow entries), and
  for one editing this skill or `improve-system`. `find-and-check-pr.sh` now exits 2 with the reason
  printed next to the file for: anything under `review-improve-system-pr/` or `improve-system/`;
  any repo path named in a `settings.json` string at the PR base or added by the PR (allow entries
  and hook commands; `~/.claude/...` maps to `dotfiles/bosko/claude/...`, absolute and
  `REVIEW_SAFE_HOME`-rooted paths to the repo; a glued trailing `*` counts as a prefix); and the
  shared libs (`.claude/lib/`, `.claude/skills/lib/`, `dotfiles/bosko/claude/skills/lib/`). Shared-lib
  edits were already exit 2 (outside `skills/<name>/{scripts,...}`), they just carried no reason.
  Exit 2 means "human must read this", so a legitimate routine edit to e.g. `secret-scan.sh` is
  flagged too — intended. Still NOT covered: an allow entry the PR adds for a script that already
  exists unchanged (the Step 2 read-through must catch it), and a helper file that an allow-listed
  script calls from the same `scripts/` dir without being named in settings.
  `settings.json` at the PR base is now fetched on every run (it defines the trusted set), so a
  failed fetch is exit 3 even when the PR does not touch settings.
- **Renames hide the old path.** `gh pr view --json files` lists a renamed file only under its new
  name. The script also reads REST `pulls/N/files` and checks each `previous_filename`, so renaming
  a trusted/gate file away is still flagged. The REST field names and the `// empty` filter were
  confirmed live on PR #70 (a modify/add PR), but no PR in this repo's history contains a rename or
  a delete, so the renamed branch and the "deleted file is listed under its old path" assumption
  are exercised only by the stub tests, not against a real GitHub response.
- **Merge is pinned and CI-gated.** `gh pr merge` alone merges a red PR and whatever commit is
  the head at that moment. Step 4 runs `scripts/ci-gate.sh <pr> <PR_HEAD_SHA>` (waits on
  `gh pr checks --watch`, and fails unless the head still equals the reviewed SHA before and
  after), then passes `--match-head-commit <PR_HEAD_SHA>` (the SHA the guardrail script printed).
