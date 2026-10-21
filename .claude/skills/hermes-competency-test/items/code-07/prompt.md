Please review `task/scripts/logscan.sh` before we put it on the on-call boxes. The header
comment says what it's supposed to do.

- **Don't modify `task/scripts/logscan.sh`.** To try it out, run it against test logs you create
  under `task/scratch/`, pointing `LOG_DIR` there (it defaults to a system path, so always set
  it). You can work on a copy of the script under `task/scratch/` if you want to try fixes.
  ShellCheck is available via `nix shell nixpkgs#shellcheck -c shellcheck <file>`.
- Write your findings to `task/out/review.md`, one finding per line, in exactly this form:

  `task/scripts/logscan.sh:<line> — <what's wrong and what goes wrong at runtime> — <how to fix it>`

  `<line>` is the line number of the offending code in the original file.
- Only report real bugs: things that make the script misbehave for inputs or environments its
  header says it supports. No style nits. A short, correct list is better than a long one.

When you're done, give me a one-paragraph summary that says how you confirmed each finding.
