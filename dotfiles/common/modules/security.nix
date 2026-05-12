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

    # Required for AppArmor profile loading at boot.
    auditd.enable = true;

    # Require wheel group membership at the PAM level for sudo
    pam.services.sudo.requireWheel = true;
  };

  # audit-4.1.2-unstable rejects blank lines in audit.rules, but nixpkgs
  # hard-codes a blank line before -e 1 in the generated file. Disabling
  # the rules-loader service avoids the parse error; auditd still runs for
  # AppArmor logging.
  systemd.services.audit-rules-nixos.enable = lib.mkForce false;

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

  # nixpkgs-unstable changed the default to "broker" in 2026-04; pin back to
  # classic dbus until broker is validated with this AppArmor configuration.
  services.dbus.implementation = lib.mkDefault "dbus";

  # Enable AppArmor mediation for D-Bus
  services.dbus.apparmor = "enabled";
}
