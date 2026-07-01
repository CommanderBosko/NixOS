{ pkgs, ... }:

{
  # System wide fonts
  fonts.packages = with pkgs; [
    corefonts
    font-awesome
    liberation_ttf
    nerd-fonts.code-new-roman
    noto-fonts
    noto-fonts-cjk-sans
  ];

  # Expose all fonts under /run/current-system/sw/share/X11/fonts.
  fonts.fontDir.enable = true;

  # OnlyOffice ignores fontconfig and only scans FHS paths (/usr/share/fonts,
  # /usr/share/X11/fonts, ~/.fonts, ~/.local/share/fonts), none of which exist
  # on NixOS — so bridge one of them to the fontDir tree above.
  systemd.tmpfiles.rules = [
    "L+ /usr/share/fonts - - - - /run/current-system/sw/share/X11/fonts"
  ];
}
