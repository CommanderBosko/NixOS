# Why this publishes an Artifact instead of linking the local path

Load this if you're tempted to link the raw local file path instead of publishing an Artifact — read this first.

The first build of this skill linked the file with a raw `file:///...` URI. Live testing
(2026-09-04) showed Discord never renders `file://` (or any non-`http(s)` scheme) as a
clickable link, in any client, by design -- it's an anti-abuse restriction, not a styling
gap, so no payload formatting works around it. The user chose to fix this by publishing the
reported file as a Claude Artifact and linking to *that* instead -- a real `https://` URL
Discord does auto-link, and one that opens from any device, not just this machine.

**Trade-off, accepted knowingly**: this means the file's content leaves the local machine --
it's published (starts private, but shareable, and may be cached/indexed once shared). Don't
send anything through this skill you wouldn't want published. This is a real behavior
change from the original design, not a cosmetic one -- if a future caller needs a link that
never leaves the machine, that's a different, unsolved requirement; don't quietly revert to
`file://` to get there, it doesn't work.

## Gotchas backing this up

- **`file://` links are never clickable in Discord, on any device -- confirmed by live
  testing (2026-09-04), not a theoretical limitation.** Discord's message renderer only
  auto-links `http(s)://` URLs; every other scheme (including `file://`, `vscode://`, etc.)
  renders as inert plain text regardless of markdown formatting, as a deliberate anti-abuse
  restriction with no client-side workaround. The original build of this skill linked
  `file://` paths directly and looked correct in review, but only live posting to a real
  Discord channel surfaced that it wasn't actually a link. If you're touching this skill
  again and considering reverting to a raw local path for simplicity, don't -- it will look
  identical in testing-by-reading-the-script and silently fail to be clickable in the actual
  product.
- **Publishing an Artifact means the file's content leaves the local machine** -- this is
  the whole point of the fix above, but it's a real trade-off the caller should be aware of,
  not a free upgrade. Don't route anything through this skill that shouldn't be published,
  even privately.
