# Send Results — Setup

Provisioning the Discord webhook (one-time, human-only).

This is the one part of this skill a human has to do -- creating and configuring the actual
Discord webhook is not something an agent can do on someone else's Discord server, and the
webhook URL is a credential that must never be generated, entered, or committed by an agent
(this repo is public; secrets are sops-nix-managed and hard-limited to human-provided values
only).

1. **Create the webhook** -- in the target Discord server: Server Settings -> Integrations ->
   Webhooks -> New Webhook. Pick the channel it should post to, copy its URL (looks like
   `https://discord.com/api/webhooks/<id>/<token>`).
2. **Add it as a sops secret** -- from a separate terminal (NOT a `!` command in a Claude
   session: `!` echoes the command text, including the value, into the transcript):
   ```bash
   cd /home/bosko/NixOS
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
   umask 077; read -rs "V?Webhook URL: "; echo; printf '%s\n' "$V" > /tmp/discord_url; unset V
   .claude/skills/add-secret/scripts/sops-secret.sh set secrets/desktop.yaml discord-webhook-url /tmp/discord_url
   .claude/skills/add-secret/scripts/verify-secret.sh secrets/desktop.yaml
   rm -f /tmp/discord_url
   ```
3. **Wire it into NixOS** -- declared in `modules/claude-mcp.nix` (same shape as the
   `tailscale-mcp-env` entry there):
   ```nix
   sops.secrets."discord-webhook-url" = {
     sopsFile = ../secrets/desktop.yaml;
     owner = "bosko";
   };
   ```
   `secrets/desktop.yaml` is encrypted to the desktop hosts only (not vpn-server), and
   `claude-mcp.nix` is in `desktopModules`, so run the `shared-module-check` skill after
   editing it, not just a single-host dry-run.
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
`modules/claude-mcp.nix` declaration, add the secret value first, *then* rebuild.
