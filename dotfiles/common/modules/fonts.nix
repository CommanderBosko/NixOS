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
  # the host filesystem or fontconfig. Its /usr/share/fonts is assembled only
  # from the packages nixpkgs lists in targetPkgs (upstream only ships
  # noto-fonts-cjk-sans there) — override that input to bundle the rest of
  # the system fonts into the sandbox.
  #
  # OnlyOffice's font scanner (DocumentServer's Directory::GetFiles2) doesn't
  # follow symlinks (upstream bug: ONLYOFFICE/DocumentServer#1859). A real
  # copy (`cp -L`) at the font-package layer isn't enough on its own: even
  # when this package's own output is real files, buildFHSEnv's internal
  # rootfs-builder re-symlinks every file from every targetPkgs derivation
  # when it merges them into the sandbox's /usr (confirmed by inspecting the
  # built .../fhsenv-rootfs/usr/share/fonts/* — they were symlinks pointing
  # at our real files). That extra hop is added by buildFHSEnv itself, after
  # our derivation runs, so it also has to be undone after buildFHSEnv runs —
  # hence overriding buildFHSEnv to append an extraBuildCommands step that
  # replaces the symlinks it just created with real copies.
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

        buildFHSEnv = args: prev.buildFHSEnv (
          args
          // {
            extraBuildCommands = (args.extraBuildCommands or "") + ''
              find $out/usr/share/fonts -type l -print0 | while IFS= read -r -d "" f; do
                real="$(readlink -f "$f")"
                rm -f "$f"
                cp -L --no-preserve=mode "$real" "$f"
              done
            '';
          }
        );
      };
    })
  ];
}
