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

- **MCP names passed on a read-verb prefix alone, and a glued `*` passed as a prefix match.**
  Reproduced against the previous checker (rc=0): credential-returning reads (`get_secret`,
  `get_secret_value`, `get_access_token`, `read_password`, `list_api_keys`, `fetch_oauth_token`),
  a write hidden behind a read prefix (`search_and_purge`, `get_and_wipe`, `query_and_truncate`,
  `get_and_unlink`, `status_and_reboot`, `list_and_toggle`, `find_and_ban`, `getaway`), and names
  laundered by the server-prefix strip (`mcp__send__send_get_x`, `mcp__delete__delete_get_files`).
  Now refused: any server/tool name containing secret|token|password|passwd|credential|api key|oauth|
  private|cookie|session key (separators ignored, case-insensitive); any `_and_`/`_or_`/`_then_`
  in the tool name; a read verb that is not a whole leading word; and a leading `<server>_` is only
  stripped when it equals the server segment and the server name has no write verb. The two
  `mcp__nixos__nix*` tools are exact exceptions. Separately, an ADDED Bash entry with a `*` glued to a
  word (`ls*`, `du*`, `id*`, `git diff*`) is a command-NAME prefix match at run time (`lsof`,
  `git difftool --extcmd=...`), so only ` *` (space before the star) or an exact command is accepted.
  This only gates additions: the current `settings.json` is unchanged and still passes as a whole.
  If you ever re-add one of the current glued entries as "new" it will be refused — 21 of the 26
  today (every Bash entry ending in a glued `*`: dry-run.sh, secret-scan.sh x2, deep-eval-check.sh,
  flake-lock-diff.sh, classify-shared-file.sh, scan-session.sh, the `~/.claude/skills/lib/*` x4,
  find-skill-misfires.sh, `git -C ... diff*`, `nix flake metadata*`, `nix flake check*`,
  `nix-store -q*`, `lsblk*`, `gh run watch*`, `journalctl*`, `flatpak remote-info*`, `git fetch*`);
  the other 5 (`git -C ... status`, `git -C ... log *`, `nix eval *`, both `mcp__nixos__nix*`) pass.
  The 84-entry refusal list still refuses every entry, and no entry in the reviewer's candidate lists
  (443 entry runs across the lists, old vs new checker) went from refused to accepted — 60 went from accepted to refused,
  all glued-`*` or MCP-name cases.
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
  failed fetch is exit 3 even when the PR does not touch settings. Valid JSON is not enough: a
  base without a `permissions.allow` array (`{}`, `[]`, `null`, an API error body) is exit 3 too,
  since it would give an empty trusted set and wave through edits to every allow-listed script.
  Path spellings mapped to the repo: `$CLAUDE_PROJECT_DIR/` (also braced), `$HOME/` / `"$HOME"/`,
  `~/`, `REVIEW_SAFE_HOME`-rooted, `./`, and bare `.claude/` or `dotfiles/bosko/claude/`. Shell
  double quotes are removed before the split, so `"$HOME"/x.sh` reads as `$HOME/x.sh`. A spelling
  not on that list (a different checkout path with no `REVIEW_SAFE_HOME`, an `$XDG_*` variable, a
  path built by command substitution) is still unmapped, so the Step 2 read-through stays the net.
- **Renaming `.claude/settings.json` away used to pass.** The old name arrives only via the rename
  list, and the loop skipped the settings path unconditionally, so a PR that moved it (deleting the
  allow list and the SessionStart hook) got `GUARDRAIL: OK`. The skip now applies only when the
  PR's own file list contains it; as a rename source it falls to the boundary rule (exit 2).
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
