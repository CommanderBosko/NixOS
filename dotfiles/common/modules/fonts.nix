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
  # OnlyOffice scans this directory instead of using fontconfig.
  fonts.fontDir.enable = true;
}
