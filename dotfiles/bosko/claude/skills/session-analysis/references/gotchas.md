# Session Analysis — Gotchas

## Transcript batch sizing

- **A project's transcript count can be large** (observed: 87 for this repo, 95 for a
  long-running game project, out of full history with no since-cutoff). Don't hand a
  `transcript-scanner` agent an 80+ file batch — split into multiple ~10-15 file batches
  per project rather than one oversized agent call; it's still one message spawning all of
  them in parallel.

## `UNKNOWN` real-path projects

- **`UNKNOWN` real-path projects have zero transcripts by construction** (observed:
  4 of 12 local projects on 2026-09-03 had only a pruned `memory/` dir left, no `.jsonl` at
  all) — don't try to guess a real path for these via un-slugifying; the manifest already
  marks them, just skip mining and let `improve-memory` still see them for the memory-only
  hygiene pass.
