Write a Bash script, `task/prune-backups.sh`, that prunes old backup archives. Spec:

**Usage:** `prune-backups.sh [-n] [-k KEEP] DIR`

**What counts as a backup archive.** A regular file directly inside `DIR` (not in a subdirectory)
whose name matches `<prefix>-<YYYYMMDD>-<HHMMSS>.tar.gz`:

- `<prefix>` is any non-empty string. It may contain spaces, hyphens, dots and glob characters such
  as `*`, and it may start with `-`. For example, `my-app-20261003-221500.tar.gz` has the prefix
  `my-app`.
- The date is exactly 8 digits and the time exactly 6 digits. Don't validate them as calendar values.

Everything else in `DIR` is ignored: it's never deleted and doesn't count toward KEEP. That includes
non-matching names, directories (even when the name matches), symlinks (even when they point to a
regular file) and anything inside subdirectories.

**Behaviour**

- Group the archives by prefix. In each group keep the KEEP newest and delete the rest. "Newest" is
  decided by the date and time in the file name, not by the file's modification time.
- `-k KEEP` sets how many to keep per prefix. It must be a positive integer (1 or more). The default
  is 3.
- `-n` is a dry run: report what would be deleted and delete nothing.
- Options come before `DIR`, in any order (`-n -k 2 DIR` and `-k 2 -n DIR` both work).
- Output: for each deleted archive, print exactly one line to stdout, `removed <name>`. In a dry run,
  print `would remove <name>` instead. `<name>` is the bare file name, without the directory. Line
  order doesn't matter, and nothing else goes to stdout.
- Exit 0 on success, including when there's nothing to delete.
- Usage errors exit 2 with a message on stderr and delete nothing. Usage errors are: an unknown
  option, a missing `DIR`, an extra argument after `DIR`, a KEEP that isn't a positive integer, and a
  `DIR` that doesn't exist or isn't a directory.
- You may assume file names never contain a newline.

**Requirements**

- Bash 5 plus GNU coreutils/findutils only (no Python, Perl, etc.). Start it with
  `#!/usr/bin/env bash` and make it executable.
- It must be shellcheck-clean: `nix shell nixpkgs#shellcheck -c shellcheck task/prune-backups.sh`
  must print nothing.
- Test it before you tell me it's done. Make your test directories under `task/scratch/`, not in
  `/tmp`.

When you're done, tell me how you tested it and anything in the spec you had to interpret.
