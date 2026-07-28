{ config, lib, ... }:

{
  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    nvidia = {
      # Modesetting is required.
      modesetting.enable = true;

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      # Enable this if you have graphical corruption issues or application crashes after waking
      # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
      # of just the bare essentials.
      powerManagement.enable = false;

      # Fine-grained power management. Turns off GPU when not in use.
      # Experimental and only works on modern Nvidia GPUs (Turing or newer).
      powerManagement.finegrained = false;

      # Use the NVidia open source kernel module (not to be confused with the
      # independent third-party "nouveau" open source driver).
      # Support is limited to the Turing and later architectures (needs GSP
      # firmware). Full list of supported GPUs is at:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # Only available from driver 515.43.04+
      # mkDefault so pre-Turing hosts (e.g. natalie-laptop's Pascal-era dGPU,
      # which fails NVRM probe under the open module) can override to false.
      open = lib.mkDefault true;

      # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.
      nvidiaSettings = true;

      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      # mkDefault so hosts whose GPU has aged out of the current stable branch
      # (e.g. natalie-laptop's Pascal-era dGPU) can override to a legacy branch.
      package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  # Niri (Smithay-based, not wlroots) allocates buffers via GBM and doesn't
  # auto-select the nvidia vendor lib the way KWin does — without these,
  # XWayland/GLX apps and hardware video decode can silently fall back to
  # software rendering under a Wayland session on this GPU.
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
  };
}
