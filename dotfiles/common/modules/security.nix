{ config, lib, pkgs, ... }:

{
  security = {
    apparmor = {
      enable = true;
      killUnconfinedConfinables = false;
    };

    # Required for AppArmor profile loading at boot
    auditd.enable = true;

    # Require wheel group membership at the PAM level for sudo
    pam.services.sudo.requireWheel = true;
  };

  # nixpkgs bug workaround: the AppArmor rules generator rejects non-absolute
  # PAM module paths, but PAM include directives (e.g. "include login") are
  # service-name references, not .so paths. Clear the affected rules and
  # preserve the PAM behaviour with explicit text overrides.
  # Only applied when SDDM is actually enabled (not on headless servers).
  security.pam.services.sddm = lib.mkIf config.services.displayManager.sddm.enable {
    rules = lib.mkForce {
      auth = { };
      account = { };
      password = { };
      session = { };
    };
    text = lib.mkForce ''
      account include login
      auth    substack login
      password substack login
      session  include login
    '';
  };

  security.pam.services.sddm-autologin = lib.mkIf config.services.displayManager.sddm.enable {
    rules = lib.mkForce {
      auth = { };
      account = { };
      password = { };
      session = { };
    };
    text = lib.mkForce ''
      account include sddm
      auth requisite ${pkgs.linux-pam}/lib/security/pam_nologin.so
      auth required  ${pkgs.linux-pam}/lib/security/pam_succeed_if.so uid >= 1000 quiet
      auth required  ${pkgs.linux-pam}/lib/security/pam_permit.so
      password include sddm
      session  include sddm
    '';
  };

  # Prevent replacing the running kernel (disables kexec)
  security.protectKernelImage = true;

  # Enforce full ASLR
  boot.kernel.sysctl."kernel.randomize_va_space" = 2;

  boot.kernelParams = [ "audit=1" ];

  services.dbus.apparmor = "enabled";
}
