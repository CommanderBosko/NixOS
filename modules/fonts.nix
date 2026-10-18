{ pkgs, ... }:

let
  systemFonts = with pkgs; [
    corefonts
    fira-code # DMS's expected monospace font
    font-awesome
    inter # DMS's expected UI font (ships "Inter Variable")
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
  # the host filesystem or fontconfig; nixpkgs only bundles noto-fonts-cjk-sans
  # into it. extraFontPackages adds the rest of the system fonts. nixpkgs copies
  # them into a real-file fonts dir itself, working around OnlyOffice's
  # symlink-blind font scanner (ONLYOFFICE/DocumentServer#1859).
  nixpkgs.overlays = [
    (final: prev: {
      onlyoffice-desktopeditors = prev.onlyoffice-desktopeditors.override {
        extraFontPackages = systemFonts;
      };
    })
  ];
}
