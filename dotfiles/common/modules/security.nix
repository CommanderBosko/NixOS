{ pkgs, ... }:

{
  security = {
    # Apparmor
    apparmor = {
      enable = true;
      packages = with pkgs; [
        apparmor-profiles
        apparmor-utils
      ];
    };
  };
}
