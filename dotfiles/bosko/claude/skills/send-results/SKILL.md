---
name: send-results
description: Publish a file as a Claude Doc (via the Claude Docs connector) and post a short summary + the doc's link to a Discord channel via webhook. Generic and callable by any skill, not just the dream suite -- minimal contract, just a file path and a summary string. Use when the user says "/send-results", "post this to Discord", "send me the results in Discord", or when another skill (e.g. dream) needs to report a finished report.
---

# Send Results

Posts one Discord message: a short summary plus a real clickable link to the reported
file. Deliberately generic -- any current or future skill can call this with nothing more
than a file path and a summary, without knowing anything about Discord, webhooks, sops, or
Claude Docs.

## Arguments

Invocation shape: `<file-path> <summary...>`.

- **`<file-path>`** (required) -- path to the file being reported on. Must exist.
- **`<summary...>`** (required) -- everything after the file path, as free text. Keep it
  short (a sentence or two) -- the file itself is the detail, this is the headline.

## Why this publishes a Claude Doc instead of linking the local path

Tempted to link the raw file path instead of publishing? See `references/why-artifact-not-file-link.md` -- `file://` links were tried and confirmed dead in Discord; don't revert. Same file explains the 2026-11-03 switch from a hand-written HTML artifact page to a Claude Doc (user standing rule: documents go in Claude Docs).

## Step 1 -- Read the file and pick a title

Read `<file-path>`. Pick a `<title>`: a short noun phrase derived from the filename, e.g.
`dream-test.txt` -> "Dream Test", `overview-20260904.md` -> "Memory Overview".

## Step 2 -- Create the doc

Call `mcp__claude_ai_Claude_Docs__batch` once, as the first docs call (a doc's birth needs
no `guide` call first). Don't load `artifact-design` and don't write HTML -- this skill no
longer publishes an HTML artifact page.

```
batch(
  container = {"kind":"project","create":{"name":"<title>",
    "doc":{"blocks":{"asof":{"type":"date","value":"<today, YYYY-MM-DD>"},
                     "me":{"type":"mention","user":"me"}},
           "markdown":"# <title>\n\n<?claude block asof?> · <?claude block me?>\n\n<body>"}}},
  batch = [])
```

`<body>` is the file's content, sent whole in this one call (nobody is watching a
notification doc fill, so the section-by-section fill is unnecessary):

- **`.md` file** -- the content as-is (pipe tables, lists and `[links](url)` render natively).
  If it opens with its own `# ` H1, drop that line -- the `# <title>` above replaces it.
- **Anything else** (`.txt`, `.log`, ...) -- the content inside a fenced code block, using a
  fence longer than the longest backtick run in the content.

The ack's trailer carries the doc's link when `created.bound:true`. `bound:false` (a notice,
no link) or a refused call (it names a `code`; see `guide(items=["refusal.<code>"])`) means
there is no link: stop, report why, and **don't post to Discord** and **don't fall back to an
HTML artifact page** -- a failed notification is reported, not papered over. If the Docs tools
aren't available in this session at all, same: report that and stop.

No `Artifact` `open` call is needed -- the person gets the doc through the Discord link.

## Step 3 -- Post to Discord

```bash
~/.claude/skills/send-results/scripts/post-discord.sh <doc-url> <summary...>
```

The script reads the webhook URL from the sops-nix secret at
`/run/secrets/discord-webhook-url` and POSTs a JSON payload containing the summary and the
doc link. It exits non-zero with a clear, actionable stderr message if the secret isn't
configured yet (see Setup below) or the POST itself fails (bad/revoked webhook, network
issue) -- relay that message to the user rather than treating a failed send as if it
succeeded.

## Step 4 -- Report

Tell the caller whether the post succeeded, the doc URL used, and if it failed, why
(from the script's stderr).

## Setup -- provisioning the Discord webhook (one-time, human-only)

Creating and configuring the Discord webhook is a one-time, human-only bootstrap step --
see `references/setup.md` for the full procedure (create the webhook, add it as a sops
secret in `secrets/desktop.yaml`, wire it into `modules/claude-mcp.nix`, rebuild, test).

## Scripts

- `scripts/post-discord.sh <url> <summary...>` -- the actual webhook POST (Step 3). Handles
  missing-secret and failed-POST cases with clear stderr messages; truncates an oversized
  summary to stay under Discord's 2000-char content cap. Takes any URL -- it doesn't know or
  care that the caller built it via a Claude Docs create.

## Gotchas

- **Script paths:** use the absolute path from this skill's Base directory line, never a bare `scripts/...` -- see `~/.claude/skills/lib/script-paths.md`.
- **Never accept a webhook URL as something to type into `sops-secret.sh` on the user's
  behalf from a value they pasted into chat** -- treat it exactly like any other credential
  hard-limit: hand off the exact commands (Setup above) and let the user run them in their
  own terminal. That includes capturing the value: never as a `!` command in the session
  (`!` echoes the command text, value included, into the transcript) — a separate terminal
  with a hidden `read -rs` prompt only.
- **Docs-connector instructions are session-scoped.** The `Claude_Docs` tools only exist in sessions where the connector is attached; a headless/cloud caller without it can't create the doc -- report that rather than substituting a different publish path.
- See `references/why-artifact-not-file-link.md` for the `file://`-links-don't-work incident and the leaves-the-machine trade-off, before touching how this skill links its output.
