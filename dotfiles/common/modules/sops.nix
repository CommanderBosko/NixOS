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
    sopsFile = ../../../secrets/common.yaml;
    neededForUsers = true;
  };
  sops.secrets."natty-hashedPassword" = {
    sopsFile = ../../../secrets/common.yaml;
    neededForUsers = true;
  };
}
