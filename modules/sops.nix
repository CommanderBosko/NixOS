{ inputs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # Each host derives its age identity from its own SSH ed25519 host key, so no
  # extra key material has to be distributed — the host that owns the key can
  # decrypt the secrets encrypted to it.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Shared secrets (all hosts). Login password hashes must be present before
  # user accounts are created, hence neededForUsers (decrypted early to
  # /run/secrets-for-users using the host key).
  sops.secrets."bosko-hashedPassword" = {
    sopsFile = ../secrets/common.yaml;
    neededForUsers = true;
  };
  sops.secrets."natty-hashedPassword" = {
    sopsFile = ../secrets/common.yaml;
    neededForUsers = true;
  };

  # Tailscale OAuth client credentials for the tailscale-mcp Claude Code
  # connector (bosko-only, wired in dotfiles/bosko/bosko-claude.nix). An
  # env-file-style secret like pinchflat-env (hosts/gaming/pinchflat.nix) —
  # its decrypted content is two shell-sourceable KEY=VALUE lines, sourced
  # by a wrapper at MCP-server-launch time so the raw values never sit in
  # ~/.claude.json. owner=bosko so a user-level activation script can read
  # it without root.
  sops.secrets."tailscale-mcp-env" = {
    sopsFile = ../secrets/common.yaml;
    owner = "bosko";
  };

  # Discord webhook URL for the send-results Claude Code skill (bosko-only,
  # wired in dotfiles/bosko/claude/skills/send-results). owner=bosko so the
  # skill's script can read it without root. The secret value itself is
  # added by the user directly (never by an agent) via add-secret's
  # sops-secret.sh -- see send-results/SKILL.md's Setup section.
  sops.secrets."discord-webhook-url" = {
    sopsFile = ../secrets/common.yaml;
    owner = "bosko";
  };
}
