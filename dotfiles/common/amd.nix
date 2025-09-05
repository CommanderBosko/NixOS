{ config, lib, pkgs, ... }:

{
  # Load AMDGPU driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      mesa
      amdvlk
    ];

    extraPackages32 = with pkgs; [
      driversi686Linux.mesa
      driversi686Linux.amdvlk
    ];
  };

  # If you need ROCm (compute / OpenCL), uncomment:
  # hardware.amdgpu.opencl.enable = true;
  # environment.systemPackages = with pkgs; [
  #   rocmPackages.clr
  # ];
}
