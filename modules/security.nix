{ config, lib, pkgs, ... }:

{
  security = {
    apparmor = {
      enable = true;
      # false: processes without an AppArmor profile are not killed — most
      # desktop applications on NixOS lack profiles, so killing them would
      # disrupt normal desktop use. MAC enforcement still applies to profiled
      # applications (e.g. dbus, cups).
      killUnconfinedConfinables = false;
    };

    # Required for AppArmor profile loading at boot.
    auditd.enable = true;

    # Require wheel group membership at the PAM level for sudo
    pam.services.sudo.requireWheel = true;

    # Show a "*" for each character typed at the sudo password prompt so the
    # length of what you've entered is visible. (The CVE-2019-18634 pwfeedback
    # stack overflow was fixed in sudo 1.8.31; current sudo is unaffected.)
    sudo.extraConfig = "Defaults pwfeedback";
  };

  # audit-4.1.2-unstable rejects blank lines in audit.rules, but nixpkgs
  # hard-codes a blank line before -e 1 in the generated file. Disabling
  # the rules-loader service avoids the parse error; auditd still runs for
  # AppArmor logging.
  systemd.services.audit-rules-nixos.enable = lib.mkForce false;

  # nixpkgs bug workaround (apparmor-parser-5.0.0, found 2026-07-17): the
  # apparmor-utils "aa-remove-unknown" script (apparmor.service's
  # ExecReload) hardcodes a path to apparmor-parser's
  # lib/apparmor/rc.apparmor.functions, which this build of apparmor-parser
  # doesn't actually ship — every activation that needs to reload apparmor
  # policies (any rebuild that changes anything in the profile closure) was
  # failing outright with "Failed to reload apparmor.service", blocking
  # `nh os boot`'s test-activation entirely. AppArmor's actual policy
  # enforcement is unaffected (confirmed: the boot-time initial load
  # succeeds fine, only the incremental reload path is broken). Disabling
  # reloadIfChanged makes activation use a full restart (stop+start, i.e.
  # aa-teardown twice) instead of the broken ExecReload when the policy set
  # changes — same net effect, just via the working code path.
  systemd.services.apparmor.reloadIfChanged = lib.mkForce false;

  # nixpkgs bug workaround: the AppArmor rules generator rejects non-absolute
  # PAM module paths, but PAM include directives (e.g. "include login") are
  # service-name references, not .so paths. Clear the affected rules attrsets
  # and preserve identical PAM behaviour with explicit text overrides.
  # Only applied when SDDM is actually enabled (not on the headless vpn-server).
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

  # Explicitly select dbus-broker as the D-Bus implementation. Without this,
  # nix-flatpak's unpinned nixpkgs input (which still defaults to "dbus") wins
  # in module merging and silently keeps the old dbus-daemon on all desktop hosts.
  services.dbus.implementation = "broker";
}
