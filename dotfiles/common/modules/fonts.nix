{ pkgs, ... }:

let
  systemFonts = with pkgs; [
    corefonts
    font-awesome
    liberation_ttf
    nerd-fonts.code-new-roman
    noto-fonts
    noto-fonts-cjk-sans
  ];
in
{
  # System wide fonts
  fonts.packages = systemFonts;

  # Expose all fonts under /run/current-system/sw/share/X11/fonts.
  fonts.fontDir.enable = true;

  # OnlyOffice runs in its own buildFHSEnv/bubblewrap sandbox and never sees
  # the host filesystem or fontconfig. Its /usr/share/fonts is assembled only
  # from the packages nixpkgs lists in targetPkgs (upstream only ships
  # noto-fonts-cjk-sans there) — override that input to bundle the rest of
  # the system fonts into the sandbox.
  nixpkgs.overlays = [
    (final: prev: {
      onlyoffice-desktopeditors = prev.onlyoffice-desktopeditors.override {
        noto-fonts-cjk-sans = prev.symlinkJoin {
          name = "onlyoffice-fonts";
          paths = systemFonts;
        };
      };
    })
  ];
}
