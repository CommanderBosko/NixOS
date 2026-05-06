{ config, lib, pkgs, ... }:

{
  security = {
    apparmor = {
      enable = true;
      # false: processes without an AppArmor profile are not killed — most
      # desktop applications on NixOS lack profiles, so killing them would
      # disrupt normal desktop use. MAC enforcement still applies to profiled
      # applications (e.g. dbus, cups). Revisit per-host for the server.
      killUnconfinedConfinables = false;
    };

    # Required for AppArmor profile loading at boot. Enabling auditd also
    # implicitly sets security.audit.enable = true via auditd.nix. The
    # audit.rules list must be non-empty — see the sentinel comment below.
    auditd.enable = true;

    # Require wheel group membership at the PAM level for sudo
    pam.services.sudo.requireWheel = true;
  };

  # audit-4.1.2-unstable treats blank lines in audit.rules as parse errors,
  # causing audit-rules-nixos.service to fail on every activation. When
  # security.audit.rules = [], lib.concatLines [] produces "" which leaves a
  # blank line between the -r 0 and -e 1 directives. A bare comment is a
  # valid no-op auditctl rule that prevents the empty-list code path.
  security.audit.rules = [ "# NixOS managed audit configuration" ];

  # nixpkgs bug workaround: the AppArmor rules generator rejects non-absolute
  # PAM module paths, but PAM include directives (e.g. "include login") are
  # service-name references, not .so paths. Clear the affected rules attrsets
  # and preserve identical PAM behaviour with explicit text overrides.
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

  # Enable audit logging in the kernel
  boot.kernelParams = [ "audit=1" ];

  # Enable AppArmor mediation for D-Bus
  services.dbus.apparmor = "enabled";
}
