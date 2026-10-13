# Wikilink classification: near-miss vs. unresolved

Load this if you're tempted to fix or flag a `WIKILINK_UNRESOLVED` finding from
`scripts/find-memory-issues.sh`, or if you doubt the near-miss-vs-unresolved split itself.

**A `WIKILINK_UNRESOLVED` finding is not a bug.** `save-memory` deliberately allows
linking to a memory that doesn't exist yet, as a marker for "worth writing later." Only
`WIKILINK_NEAR_MISS` (a link that clearly matches an existing file under a different
hyphen/underscore spelling) is a real staleness fix — unresolved links are almost always
intentional forward-references or references to skill names, not memory slugs at all
(e.g. `[[bump-input]]`, `[[pin-input]]`), and should not be touched. The
near-miss-vs-unresolved classification method itself is confirmed sound against this
repo's own memory dir (checked repeatedly, most recently 2026-09-04, after `dream`'s
first full-history run had already normalized the near-misses found on 2026-09-03) —
don't expect any specific count to still be reproducible; re-run
`scripts/find-memory-issues.sh` live rather than trusting a cached number here.
