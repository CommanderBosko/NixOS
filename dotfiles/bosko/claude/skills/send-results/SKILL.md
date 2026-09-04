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

This is the one part of this skill a human has to do -- creating and configuring the actual
Discord webhook is not something an agent can do on someone else's Discord server, and the
webhook URL is a credential that must never be generated, entered, or committed by an agent
(this repo is public; secrets are sops-nix-managed and hard-limited to human-provided values
only).

1. **Create the webhook** -- in the target Discord server: Server Settings -> Integrations ->
   Webhooks -> New Webhook. Pick the channel it should post to, copy its URL (looks like
   `https://discord.com/api/webhooks/<id>/<token>`).
2. **Add it as a sops secret** -- run this yourself (don't paste the URL into a chat
   transcript with an agent if you can avoid it):
   ```bash
   cd /home/bosko/NixOS
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
   .claude/skills/add-secret/scripts/sops-secret.sh set secrets/common.yaml discord-webhook-url "<paste-the-webhook-url>"
   .claude/skills/add-secret/scripts/verify-secret.sh secrets/common.yaml
   ```
3. **Wire it into NixOS** -- add to `modules/sops.nix` (same shape as the existing
   `tailscale-mcp-env` entry):
   ```nix
   sops.secrets."discord-webhook-url" = {
     sopsFile = ../secrets/common.yaml;
     owner = "bosko";
   };
   ```
   `modules/sops.nix` is part of `commonModules` (applies to every host), so run the
   `shared-module-check` skill after this edit, not just a single-host dry-run.
4. **Rebuild** whichever host(s) should be able to send Discord notifications (at minimum
   the one you'll run `/dream` from) -- `nh os boot /home/bosko/NixOS` then reboot, or
   `nh os switch` if you want it live immediately. Decryption happens at activation, so a
   plain eval/dry-run won't make the secret readable yet.
5. **Test it**: `/send-results <any-existing-file> "test message"` and confirm it lands in
   the right channel with a clickable link that opens the published page.

**Order matters**: add the secret value (step 2) *before* the nix declaration (step 3) lands
and gets rebuilt anywhere -- a `sops.secrets` entry referencing a key that doesn't exist yet
in the encrypted file will fail to decrypt at activation, which can break a rebuild for
every host sharing that module. If you're applying this from a PR that already added the
`modules/sops.nix` declaration, add the secret value first, *then* rebuild.

## Scripts

- `scripts/post-discord.sh <url> <summary...>` -- the actual webhook POST (Step 4). Handles
  missing-secret and failed-POST cases with clear stderr messages; truncates an oversized
  summary to stay under Discord's 2000-char content cap. Takes any URL -- it doesn't know or
  care that the caller built it via an Artifact publish.

## Gotchas

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
- **This skill is global/repo-managed** -- always invoke `post-discord.sh` by the absolute
  `~/.claude/skills/send-results/scripts/...` path shown when the skill launches, never a
  bare `scripts/...` path (resolves against the wrong cwd).
- **Never accept a webhook URL as something to type into `sops-secret.sh` on the user's
  behalf from a value they pasted into chat** -- treat it exactly like any other credential
  hard-limit: hand off the exact commands (Setup above) and let the user run them in their
  own terminal.
- **Publishing an Artifact means the file's content leaves the local machine** -- this is
  the whole point of the fix (see "Why this publishes an Artifact" above), but it's a real
  trade-off the caller should be aware of, not a free upgrade. Don't route anything through
  this skill that shouldn't be published, even privately.
