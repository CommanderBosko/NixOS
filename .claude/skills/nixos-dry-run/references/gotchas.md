# nixos-dry-run gotchas

- **The switch/boot recommendation is a keyword heuristic, not exhaustive.** It scans the raw
  diff text for package-name substrings (`nvidia`, `sddm`, `niri`, `linux-`, etc.), so it can
  miss changes that don't show up under those names (e.g. a security-critical config change
  wrapped in a differently-named derivation) or a low-risk service that happens to have a
  session-risk keyword in an unrelated path. Treat it as a strong default suggestion, not an
  infallible verdict — still show the user the underlying diff.

- **`nh os boot --dry`'s output is a redrawing TUI tree**, not a flat log — most of it is
  self-overwriting progress-bar escape sequences, and the actually useful summary (the
  `<<<`/`>>>` store-path diff plus `PATHS:`/`SIZE:`/`DIFF:` lines) sits at the very end.
  Piping through a large `tail -N` (e.g. `tail -60`) still surfaces a wall of tree/progress
  noise. Prefer `tail -8` (the summary is always the last handful of lines) or
  `grep -E '^(PATHS|SIZE|DIFF):'` to jump straight to the change summary.

- **Only checks the local host — takes no host argument.** `nh os boot --dry` always builds
  *this machine's* config, even if you pass a different host name; the skill has no argument
  handling, so it's silently ignored rather than erroring. To verify a host you're not on
  (e.g. `natalie-laptop`, `vpn-server`), use `deep-eval-check` (every `.flakeHosts` host) or
  `shared-module-check` (impact of a shared-file edit) instead — this tripped us up
  2026-07-18 trying to dry-run `natalie-laptop` from `gaming`.
