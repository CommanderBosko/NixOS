# The FamDash family dashboard service (Express app, port 3000).
#
# The code comes from the private CommanderBosko/FamDash repo via the `famdash`
# flake input, packaged by ./famdash-package.nix, which also patches the app to
# keep its database at $FAMDASH_DB instead of beside server.js (the store is
# read-only). All state is one file, /var/lib/famdash/db.json.
{ inputs, pkgs, ... }:

let
  famdash = pkgs.callPackage ./famdash-package.nix { src = inputs.famdash; };
in
{
  # Static (not DynamicUser) so a restored db.json can be chowned to a stable name.
  users.groups.famdash = { };
  users.users.famdash = {
    isSystemUser = true;
    group = "famdash";
  };

  systemd.services.famdash = {
    description = "FamDash family dashboard";
    wantedBy = [ "multi-user.target" ];
    # The server binds every interface, so it needs no more than the stack up.
    after = [ "network.target" ];
    environment.FAMDASH_DB = "/var/lib/famdash/db.json";
    serviceConfig = {
      ExecStart = "${famdash}/bin/famdash";
      User = "famdash";
      Group = "famdash";
      StateDirectory = "famdash";
      StateDirectoryMode = "0750";
      Restart = "always";
      RestartSec = 5;

      # Sandbox: the app only serves HTTP and writes its own state directory.
      # (No MemoryDenyWriteExecute: V8's JIT needs writable+executable pages.)
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [ "@system-service" "~@privileged" ];
      UMask = "0077";
    };
  };
}
