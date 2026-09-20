---
name: send-results
description: Publish a file as a Claude Artifact and post a short summary + the artifact's link to a Discord channel via webhook. Generic and callable by any skill, not just the dream suite -- minimal contract, just a file path and a summary string. Use when the user says "/send-results", "post this to Discord", "send me the results in Discord", or when another skill (e.g. dream) needs to report a finished artifact.
---

# Send Results

Posts one Discord message: a short summary plus a real clickable link to the reported
file. Deliberately generic -- any current or future skill can call this with nothing more
than a file path and a summary, without knowing anything about Discord, webhooks, sops, or
Artifacts.

## Arguments

Invocation shape: `<file-path> <summary...>`.

- **`<file-path>`** (required) -- path to the file being reported on. Must exist.
- **`<summary...>`** (required) -- everything after the file path, as free text. Keep it
  short (a sentence or two) -- the file itself is the detail, this is the headline.

## Why this publishes an Artifact instead of linking the local path

Tempted to link the raw file path instead of publishing an Artifact? See `references/why-artifact-not-file-link.md` -- `file://` links were tried and confirmed dead in Discord; don't revert.

## Step 1 -- Read the file and load artifact-design

Read `<file-path>`. Then load the `artifact-design` skill (Skill tool) -- this is mandatory
before writing any artifact HTML, no exceptions, per the Artifact tool's own rules.

## Step 2 -- Wrap the content as a minimal HTML page

Write a small `.html` file (Write tool) that presents the content readably. Keep it light --
this is a notification attachment, not a designed deliverable:
- A `<title>` naming the artifact (a short noun phrase derived from the filename, e.g.
  `dream-test.txt` -> "Dream Test", `overview-20260904.md` -> "Memory Overview").
- The file's content rendered legibly -- a `<pre>` block with `white-space: pre-wrap` and a
  readable monospace/system font is entirely sufficient for a report/log/markdown file;
  don't over-invest in layout for what's fundamentally a copy of a text file.
- Follow the theme-aware and sizing rules from `artifact-design` (light/dark tokens, no
  horizontal page scroll) even for this minimal case.

Use `~/.claude/dream/.artifact-staging/<basename-of-file-path>.html` as the scratch path
(create the directory if it doesn't exist) so repeated calls don't collide with unrelated
temp files.

## Step 3 -- Publish it

Call the Artifact tool: `action: "publish"`, `file_path` = the HTML file from Step 2,
`title` = the short name from Step 2, `description` = the `<summary...>` argument verbatim,
`favicon` = `"📄"`. Note the resulting URL.

## Step 4 -- Post to Discord

```bash
~/.claude/skills/send-results/scripts/post-discord.sh <artifact-url> <summary...>
```

The script reads the webhook URL from the sops-nix secret at
`/run/secrets/discord-webhook-url` and POSTs a JSON payload containing the summary and the
artifact link. It exits non-zero with a clear, actionable stderr message if the secret isn't
configured yet (see Setup below) or the POST itself fails (bad/revoked webhook, network
issue) -- relay that message to the user rather than treating a failed send as if it
succeeded.

## Step 5 -- Report

Tell the caller whether the post succeeded, the artifact URL used, and if it failed, why
(from the script's stderr).

## Setup -- provisioning the Discord webhook (one-time, human-only)

Creating and configuring the Discord webhook is a one-time, human-only bootstrap step --
see `references/setup.md` for the full procedure (create the webhook, add it as a sops
secret, wire it into `modules/sops.nix`, rebuild, test).

## Scripts

- `scripts/post-discord.sh <url> <summary...>` -- the actual webhook POST (Step 4). Handles
  missing-secret and failed-POST cases with clear stderr messages; truncates an oversized
  summary to stay under Discord's 2000-char content cap. Takes any URL -- it doesn't know or
  care that the caller built it via an Artifact publish.

## Gotchas

- **This skill is global/repo-managed** -- always invoke `post-discord.sh` by the absolute
  `~/.claude/skills/send-results/scripts/...` path shown when the skill launches, never a
  bare `scripts/...` path (resolves against the wrong cwd).
- **Never accept a webhook URL as something to type into `sops-secret.sh` on the user's
  behalf from a value they pasted into chat** -- treat it exactly like any other credential
  hard-limit: hand off the exact commands (Setup above) and let the user run them in their
  own terminal.
- See `references/why-artifact-not-file-link.md` for the `file://`-links-don't-work incident and the leaves-the-machine trade-off, before touching how this skill links its output.
