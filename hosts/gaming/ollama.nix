{ pkgs, ... }:

{
  hardware.nvidia-container-toolkit.enable = true;

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    loadModels = [ "hermes3:8b" ];
  };
}
