{ pkgs, ... }:

{
  # Not imported by any host right now — staged for the gaming GPU swap (swap
  # nvidia.nix for this in flake.nix's gamingModules). lib.moduleSmoke.amd
  # evaluates it so it can't rot while unused.

  # Load AMDGPU driver at initrd
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Load AMDGPU driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      mesa
    ];

    extraPackages32 = with pkgs; [
      driversi686Linux.mesa
    ];
  };

  # If you need ROCm (compute / OpenCL), uncomment:
  # hardware.amdgpu.opencl.enable = true;
  # environment.systemPackages = with pkgs; [
  #   rocmPackages.clr
  # ];
}
