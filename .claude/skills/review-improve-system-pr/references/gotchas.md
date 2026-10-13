# review-improve-system-pr gotchas

- **`gh pr diff` only accepts one pathspec after `--`.** Hit for real 2026-09-05: running
  `gh pr diff <number> --repo CommanderBosko/NixOS -- file1 file2` to scope Step 2's diff to
  specific changed files failed with `accepts at most 1 arg(s), received 3`. Step 2's plain
  `gh pr diff <number> --repo CommanderBosko/NixOS` (no path filter) already shows the full
  diff — don't add a multi-file pathspec to narrow it.
