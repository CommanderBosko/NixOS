# Skill Suggestion — Gotchas

Load this when Step 1's reported cutoff looks suspiciously old.

- **`find-last-skill-invocation.sh` used to miss slash-command invocations — fixed 2026-08-10.**
  It once only grepped for assistant-initiated `Skill` tool_use entries — when this skill (or any
  other) is run the normal way, via a user-typed `/skill-suggestion`, Claude Code injects the
  instructions as user-turn content instead, so the detector never recorded it. `session-closer`
  hit this for real (2026-08-02: reported a stale 2026-07-16 cutoff when two closes had actually
  happened since), and this skill leans on the same detector as its **primary** reuse signal in
  Step 1 — a silently-wrong cutoff here directly corrupts the candidate ranking in Step 3.
  **Fixed 2026-08-10:** the script now also matches a `<command-name>/<skill-name></command-name>`
  slash-command turn (plain user-turn string content), not just `Skill` tool_use, so both count
  going forward. If the reported cutoff still looks suspiciously old given known recent activity,
  cross-check against a skill-suggestion-specific marker as a sanity check before trusting it —
  e.g. a commit that added a new skill file under `dotfiles/bosko/claude/skills/` — rather than a
  generic `chore(session):` marker, which is session-closer's own close commit and doesn't
  correlate with when skill-suggestion itself last ran.
