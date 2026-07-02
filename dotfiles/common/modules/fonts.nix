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
  #
  # OnlyOffice's font scanner (DocumentServer's Directory::GetFiles2) doesn't
  # follow symlinks (upstream bug: ONLYOFFICE/DocumentServer#1859), so a
  # symlinkJoin of the font packages is invisible to it — every file in a
  # symlinkJoin output is itself a symlink. Use a real copy (`cp -L`,
  # dereferencing) instead so the sandbox sees regular files.
  nixpkgs.overlays = [
    (final: prev: {
      onlyoffice-desktopeditors = prev.onlyoffice-desktopeditors.override {
        noto-fonts-cjk-sans = prev.runCommand "onlyoffice-fonts" { } ''
          mkdir -p $out/share/fonts
          for pkg in ${toString systemFonts}; do
            if [ -d "$pkg/share/fonts" ]; then
              cp -rL --no-preserve=mode "$pkg"/share/fonts/* $out/share/fonts/ 2>/dev/null || true
            fi
          done
        '';
      };
    })
  ];
}
