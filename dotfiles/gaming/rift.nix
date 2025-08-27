{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.stdenv.mkDerivation {
      pname = "rift";
      version = "5.1.2";

      src = pkgs.fetchurl {
        url = "https://riftforeve.online/download/debian/rift_5.1.2_amd64.deb";
        sha256 = "1af54h6j7mpaknyxydqi9aiz6g31kfwcllknhqzpv96bn2ps31lj";
      };

      nativeBuildInputs = [ pkgs.dpkg pkgs.makeWrapper ];

      unpackPhase = ''
        dpkg-deb -x $src .
      '';

      installPhase = ''
        mkdir -p $out

        # Copy everything from .deb into $out
        cp -r usr/* $out/

        # Ensure the binary is wrapped so it finds its libraries
        mkdir -p $out/bin
        makeWrapper $out/bin/rift $out/bin/rift \
          --prefix LD_LIBRARY_PATH : $out/lib

        # Install desktop entry
        mkdir -p $out/share/applications
        cat > $out/share/applications/rift.desktop <<EOF
        [Desktop Entry]
        Name=Rift
        Exec=$out/bin/rift
        Icon=rift
        Type=Application
        Categories=Game;
        EOF

        # Install icon (if available in the deb)
        if [ -f $out/share/icons/hicolor/256x256/apps/rift.png ]; then
          mkdir -p $out/share/icons/hicolor/256x256/apps
          cp $out/share/icons/hicolor/256x256/apps/rift.png \
             $out/share/icons/hicolor/256x256/apps/rift.png
        fi
      '';
    })
  ];
}
