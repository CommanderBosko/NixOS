# Local LLM server for the LAN: Ollama on this machine's GPU, reachable from the other machines
# on the home network, plus a nightly copy of the downloaded models to the NAS so a reinstall
# doesn't mean re-downloading tens of gigabytes.
{ config, lib, pkgs, ... }:

let
  cfg = config.homelab.llm;
in
{
  options.homelab.llm = {
    enable = lib.mkEnableOption "the local Ollama server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "TCP port Ollama listens on (all interfaces).";
    };

    nasTarget = lib.mkOption {
      type = lib.types.str;
      default = "backup@nas.example.com:/srv/backup/ollama-models/";
      description = "rsync destination for the nightly model copy.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      host = "0.0.0.0";
      port = cfg.port;
    };

    # Ollama holds on to VRAM while it runs, so don't start it at boot.
    # Start it by hand with `systemctl start ollama` when it's needed.
    systemd.services.ollama.wantedBy = [ ];

    systemd.services.ollama-model-backup = {
      description = "Copy downloaded Ollama models to the NAS";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.rsync}/bin/rsync -a -e '${pkgs.openssh}/bin/ssh -i ${./keys/model-backup_ed25519}' ${config.services.ollama.modelsDir}/ ${cfg.nasTarget}";
      };
    };

    systemd.timers.ollama-model-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "03:30";
        Persistent = true;
      };
    };

    # Let the other machines on the LAN reach the API.
    networking.firewall.allowedTCPPorts = [ "${toString cfg.port}" ];
  };
}
