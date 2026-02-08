{ config, pkgs, ... }:

{
  # System wide fonts
  fonts.packages = with pkgs; [
    font-awesome
    nerd-fonts.code-new-roman
    noto-fonts
    noto-fonts-cjk-sans
  ];
}
