{ config, lib, pkgs, ... }:

let
  gpuVendor = config.hardware.gpu.vendor or "nvidia"; # "amd" or "nvidia"
in
{
  options = {
    hardware.gpu.vendor = lib.mkOption {
      type = lib.types.enum [ "nvidia" "amd" ];
      default = "amd";
    };
  };

  config = {
    services.xserver.videoDrivers =
      if gpuVendor == "nvidia" then [ "nvidia" ] else [ "amdgpu" ];

    # Shared graphics settings
    hardware.graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = lib.mkIf (gpuVendor == "amd") (with pkgs; [
        mesa
        amdvlk
      ]);

      extraPackages32 = lib.mkIf (gpuVendor == "amd") (with pkgs; [
        driversi686Linux.mesa
        driversi686Linux.amdvlk
      ]);
    };

    # NVIDIA-specific settings
    hardware.nvidia = lib.mkIf (gpuVendor == "nvidia") {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };
}
