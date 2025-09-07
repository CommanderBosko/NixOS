{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "rift";
  version = "5.1.2";

  src = pkgs.fetchurl {
    url = "https://riftforeve.online/download/debian/rift_5.1.2_amd64.deb";
    sha256 = "1af54h6j7mpaknyxydqi9aiz6g31kfwcllknhqzpv96bn2ps31lj";
  };

  buildInputs = [
    pkgs.dpkg
    pkgs.makeWrapper
    pkgs.openjdk
    pkgs.alsa-lib
    pkgs.libGL
    pkgs.SDL2
    pkgs.zlib
    pkgs.libpulseaudio
    pkgs.glib
    pkgs.libX11
    pkgs.libXext
    pkgs.libXrender
  ];

  unpackPhase = ''
    mkdir unpacked
    dpkg-deb -x $src unpacked
  '';

  installPhase = ''
    mkdir -p $out/bin
    rift_bin=$(find unpacked -type f -name 'rift' -executable | head -n1)
    if [ -z "$rift_bin" ]; then
      echo "Error: Rift binary not found!"
      exit 1
    fi

    cp "$rift_bin" $out/bin/rift
    chmod +x $out/bin/rift

    # Wrap binary with runtime libraries + Java
    wrapProgram $out/bin/rift \
      --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}" \
      --set JAVA_HOME "${pkgs.openjdk}"

    # Desktop entry
    mkdir -p $out/share/applications
    cat > $out/share/applications/rift.desktop <<EOF
    [Desktop Entry]
    Name=Rift
    Comment=Rift ${version}
    Exec=$out/bin/rift
    Icon=rift
    Terminal=false
    Type=Application
    Categories=Game;
    EOF
  '';

  meta = with pkgs.lib; {
    description = "Rift ${version}";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
