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

Pick a `<title>` naming the artifact: a short noun phrase derived from the filename, e.g.
`dream-test.txt` -> "Dream Test", `overview-20260904.md` -> "Memory Overview". Then:

```bash
~/.claude/skills/send-results/scripts/wrap-html.sh <file-path> "<title>"
```

It fills `assets/wrapper-template.html` with the title and the file's HTML-escaped content
(a theme-aware `<pre>` with `white-space: pre-wrap`, per `artifact-design`'s light/dark and
no-horizontal-scroll rules), writes it to
`~/.claude/dream/.artifact-staging/<basename-of-file-path>.html` (creating the directory if
needed), and prints that path. Don't hand-write the HTML; if the page needs to change, edit
the template.

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
secret in `secrets/desktop.yaml`, wire it into `modules/claude-mcp.nix`, rebuild, test).

## Scripts

- `scripts/wrap-html.sh <file-path> <title> [out-path]` -- builds the Step 2 HTML page from
  `assets/wrapper-template.html` and prints its path. `out-path` defaults to the
  `.artifact-staging` path above; the header comment lists what the template must keep.
- `scripts/post-discord.sh <url> <summary...>` -- the actual webhook POST (Step 4). Handles
  missing-secret and failed-POST cases with clear stderr messages; truncates an oversized
  summary to stay under Discord's 2000-char content cap. Takes any URL -- it doesn't know or
  care that the caller built it via an Artifact publish.

## Assets

- `assets/wrapper-template.html` -- the Step 2 page skeleton (`{{TITLE}}` and `{{CONTENT}}`
  placeholders). `wrap-html.sh` fills it; don't fill it by hand.

## Gotchas

- **Script paths:** use the absolute path from this skill's Base directory line, never a bare `scripts/...` -- see `~/.claude/skills/lib/script-paths.md`.
- **Never accept a webhook URL as something to type into `sops-secret.sh` on the user's
  behalf from a value they pasted into chat** -- treat it exactly like any other credential
  hard-limit: hand off the exact commands (Setup above) and let the user run them in their
  own terminal. That includes capturing the value: never as a `!` command in the session
  (`!` echoes the command text, value included, into the transcript) — a separate terminal
  with a hidden `read -rs` prompt only.
- See `references/why-artifact-not-file-link.md` for the `file://`-links-don't-work incident and the leaves-the-machine trade-off, before touching how this skill links its output.
