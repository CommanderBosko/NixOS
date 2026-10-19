# Proton Mail on gaming: Proton Mail Bridge exposes the account as local
# IMAP/SMTP, and Himalaya (the CLI Hermes and the user drive) talks to it.
#
# - The address lives in sops (public repo), so the Himalaya config is a sops
#   template symlinked into ~/.config; that also stops anything (Hermes) from
#   rewriting it with an inline password.
# - The Bridge password is never in the repo or the config: the user stores it
#   once in the GNOME keyring, and Himalaya reads it with secret-tool.
# - One-time setup after the rebuild: log in to Bridge interactively, then
#   store its password (see the Hermes proton-mail skill / project memory).
{ config, pkgs, ... }:

let
  # Bridge only listens on loopback; its self-signed cert won't verify, so plain
  # IMAP/SMTP to 127.0.0.1 is the standard setup and never leaves the machine.
  password = ''password.command = "secret-tool lookup service protonmail-bridge account himalaya"'';
in
{
  services.protonmail-bridge.enable = true;

  # secret-tool, for Himalaya's password command and the one-time store step.
  environment.systemPackages = [ pkgs.libsecret ];

  sops.secrets."proton-address".sopsFile = ../../secrets/hosts/gaming.yaml;

  sops.templates."himalaya-config.toml" = {
    owner = "bosko";
    content = ''
      [accounts.proton]
      default = true
      email = "${config.sops.placeholder."proton-address"}"
      display-name = "Bosko"
      # Bridge files sent mail into Sent itself.
      message.send.save-copy = false

      imap.server = "imap://127.0.0.1:1143"
      imap.starttls = false
      imap.sasl.plain.username = "${config.sops.placeholder."proton-address"}"
      imap.sasl.plain.${password}

      smtp.server = "smtp://127.0.0.1:1025"
      smtp.starttls = false
      smtp.sasl.plain.username = "${config.sops.placeholder."proton-address"}"
      smtp.sasl.plain.${password}

      mailbox.alias.sent = "Sent"
      mailbox.alias.drafts = "Drafts"
      mailbox.alias.trash = "Trash"
      mailbox.alias.junk = "Spam"
      mailbox.alias.archive = "Archive"
    '';
  };

  # L+ replaces the old hand-written config (it held a Gmail password inline).
  systemd.tmpfiles.rules = [
    "L+ /home/bosko/.config/himalaya/config.toml - - - - ${config.sops.templates."himalaya-config.toml".path}"
  ];
}
