# Why cross-project mining needs its own lib script

Load this before changing how `scripts/scan-projects.sh` enumerates projects, or before swapping in one of the single-project lib scripts.

`find-transcript-dir.sh` / `list-transcripts-since.sh` / `find-last-skill-invocation.sh`
(in `~/.claude/skills/lib/`) all have a **single-project** contract: given one project
directory, resolve to its one transcript dir. Other skills (`session-closer`,
`skill-suggestion`, `skill-upgrade`, `skill-audit`, `save-memory`, `research`) depend on
that contract staying exactly as-is. So mining all projects uses a **new** script,
`list-all-projects.sh`, that enumerates every dir under `~/.claude/projects/*/` and prints
each one's real project path (recovered from the `cwd` field inside a `.jsonl` transcript,
not by un-slugifying the directory name -- see its header comment for why that's not safe)
paired with its transcript dir. Because it prints the *real path*, callers can still feed
that straight into `list-transcripts-since.sh` unchanged instead of forking its contract.

A project dir with no `.jsonl` files left (transcripts pruned, only a `memory/` dir
remains) prints `UNKNOWN` as its real path. Skip mining for it — there's nothing to mine —
but don't drop it silently from the manifest; `improve-memory` still wants to know it
exists for the memory-hygiene pass.
