---
name: send-results
description: Post a short summary and a file:// link back to a local file to a Discord channel via webhook. Generic and callable by any skill, not just the dream suite -- minimal contract, just a file path and a summary string. Use when the user says "/send-results", "post this to Discord", "send me the results in Discord", or when another skill (e.g. dream) needs to report a finished artifact.
---

# Send Results

Posts one Discord message: a short summary plus a `file://` link back to a real local
file. Deliberately generic — any current or future skill can call this with nothing more
than a file path and a summary, without knowing anything about Discord, webhooks, or sops.

## Arguments

Invocation shape: `<file-path> <summary...>`.

- **`<file-path>`** (required) — path to the file being reported on. Must exist.
- **`<summary...>`** (required) — everything after the file path, as free text. Keep it
  short (a sentence or two) — the file itself is the detail, this is the headline.

## Step 1 — Post it

```bash
~/.claude/skills/send-results/scripts/post-discord.sh <file-path> <summary...>
```

The script resolves the file to an absolute path, builds a `file://` link, reads the
webhook URL from the sops-nix secret at `/run/secrets/discord-webhook-url`, and POSTs a
JSON payload. It exits non-zero with a clear, actionable stderr message if: the secret
isn't configured yet (see Setup below), the file doesn't exist, or the POST itself fails
(bad/revoked webhook, network issue) — relay that message to the user rather than treating
a failed send as if it succeeded.

## Step 2 — Report

Tell the caller whether the post succeeded, and if not, why (from the script's stderr).

## Setup — provisioning the Discord webhook (one-time, human-only)

This is the one part of this skill a human has to do — creating and configuring the
actual Discord webhook is not something an agent can do on someone else's Discord server,
and the webhook URL is a credential that must never be generated, entered, or committed by
an agent (this repo is public; secrets are sops-nix-managed and hard-limited to
human-provided values only).

1. **Create the webhook** — in the target Discord server: Server Settings → Integrations →
   Webhooks → New Webhook. Pick the channel it should post to, copy its URL (looks like
   `https://discord.com/api/webhooks/<id>/<token>`).
2. **Add it as a sops secret** — run this yourself (don't paste the URL into a chat
   transcript with an agent if you can avoid it):
   ```bash
   cd /home/bosko/NixOS
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
   .claude/skills/add-secret/scripts/sops-secret.sh set secrets/common.yaml discord-webhook-url "<paste-the-webhook-url>"
   .claude/skills/add-secret/scripts/verify-secret.sh secrets/common.yaml
   ```
3. **Wire it into NixOS** — add to `modules/sops.nix` (same shape as the existing
   `tailscale-mcp-env` entry right above where this goes):
   ```nix
   sops.secrets."discord-webhook-url" = {
     sopsFile = ../secrets/common.yaml;
     owner = "bosko";
   };
   ```
   `modules/sops.nix` is part of `commonModules` (applies to every host), so run the
   `shared-module-check` skill after this edit, not just a single-host dry-run.
4. **Rebuild** whichever host(s) should be able to send Discord notifications (at minimum
   the one you'll run `/dream` from) — `nh os boot /home/bosko/NixOS` then reboot, or
   `nh os switch` if you want it live immediately. Decryption happens at activation, so a
   plain eval/dry-run won't make the secret readable yet.
5. **Test it**: `/send-results <any-existing-file> "test message"` and confirm it lands
   in the right channel.

**Order matters**: add the secret value (step 2) *before* the nix declaration (step 3)
lands and gets rebuilt anywhere — a `sops.secrets` entry referencing a key that doesn't
exist yet in the encrypted file will fail to decrypt at activation, which can break a
rebuild for every host sharing that module. If you're applying this from a PR that already
added the `modules/sops.nix` declaration, add the secret value first, *then* rebuild.

## Scripts

- `scripts/post-discord.sh <file-path> <summary...>` — the actual webhook POST (Step 1).
  Handles missing-secret, missing-file, and failed-POST cases with clear stderr messages;
  truncates an oversized summary to stay under Discord's 2000-char content cap.

## Gotchas

- **The `file://` link only resolves when clicked from the same machine that ran this
  skill.** That's an accepted limitation, not a bug — these are local dev-machine
  artifacts (memory overview files, analysis reports), not something meant to be shared
  cross-device. Don't try to "fix" this by uploading file contents to Discord instead;
  that changes the contract this skill exists to keep minimal.
- **This skill is global/repo-managed** — always invoke `post-discord.sh` by the absolute
  `~/.claude/skills/send-results/scripts/...` path shown when the skill launches, never a
  bare `scripts/...` path (resolves against the wrong cwd).
- **Never accept a webhook URL as something to type into `sops-secret.sh` on the user's
  behalf from a value they pasted into chat** — treat it exactly like any other credential
  hard-limit: hand off the exact commands (Setup above) and let the user run them in their
  own terminal. This came up explicitly when this skill was first built (2026-09-03): the
  building agent had no path to touching the secret value itself and handed off Setup
  verbatim rather than asking for the URL in-conversation.
