{ lib, pkgs, ... }:

{
  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = "sddm-astronaut-theme";
      autoNumlock = true;
      # sddm-astronaut ships the theme; qtmultimedia is needed for its
      # animated/video backgrounds under the Qt6/Wayland greeter.
      extraPackages = [ pkgs.kdePackages.qtmultimedia ];
    };
  };

  # Make the sddm-astronaut theme available to the greeter.
  environment.systemPackages = [ pkgs.sddm-astronaut ];

  # nixpkgs bug workaround: the AppArmor rules generator rejects non-absolute
  # PAM module paths, but PAM include directives (e.g. "include login") are
  # service-name references, not .so paths. Clear the affected rules attrsets
  # and preserve identical PAM behaviour with explicit text overrides.
  security.pam.services.sddm = {
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

  security.pam.services.sddm-autologin = {
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
}
