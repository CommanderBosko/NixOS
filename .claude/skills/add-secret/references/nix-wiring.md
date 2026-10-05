# add-secret — Step 4 NixOS wiring template

A secret in the file does nothing until it's declared and referenced. Remind the user (or
do it if they ask):

```nix
# declare it (in sops.nix for shared, or the relevant host module for per-host)
sops.secrets."new-key-name" = {
  sopsFile = ../../../secrets/common.yaml;   # adjust relative path to the file
  # neededForUsers = true;                    # only for user password hashes
  # owner = "someservice"; mode = "0400";     # if a service must read it
};

# reference it by its runtime path
services.foo.passwordFile = config.sops.secrets."new-key-name".path;
```

`config.sops.secrets."<name>".path` resolves to `/run/secrets/<name>`
(or `/run/secrets-for-users/<name>` when `neededForUsers = true`).
