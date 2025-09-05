{ config, lib, pkgs, ... }:

let
  # Choose GPU vendor: "nvidia" or "amd"
  gpuVendor = config.hardware.gpu.vendor or "nvidia";
in
{
  # Enable graphics stack
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = if gpuVendor == "nvidia" then
    [ "nvidia" ]
  else
    [ "amdgpu" ];

  hardware = lib.mkMerge [
    # NVIDIA-specific settings
    (lib.mkIf (gpuVendor == "nvidia") {
      nvidia = {
        modesetting.enable = true;
        powerManagement.enable = false;
        powerManagement.finegrained = false;
        open = false;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
    })

    # AMD-specific settings
    (lib.mkIf (gpuVendor == "amd") {
      opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
        extraPackages = with pkgs; [
          mesa.drivers
          amdvlk
        ];
        extraPackages32 = with pkgs; [
          driversi686Linux.mesa
          driversi686Linux.amdvlk
        ];
      };
    })
  ];
}
