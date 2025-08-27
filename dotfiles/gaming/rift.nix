{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "rift";
  version = "5.1.2";

  src = pkgs.fetchurl {
    url = "https://riftforeve.online/download/debian/rift_5.1.2_amd64.deb";
    sha256 = "1af54h6j7mpaknyxydqi9aiz6g31kfwcllknhqzpv96bn2ps31lj";
  };

  buildInputs = [ pkgs.dpkg pkgs.patchelf pkgs.openjdk ];

  unpackPhase = ''
    mkdir unpacked
    dpkg-deb -x $src unpacked
  '';

  buildInputs = [ pkgs.dpkg pkgs.makeWrapper pkgs.openjdk ];

installPhase = ''
  mkdir -p $out/bin
  rift_bin=$(find unpacked -type f -name 'rift' -executable | head -n1)
  if [ -z "$rift_bin" ]; then
    echo "Error: Rift binary not found!"
    exit 1
  fi

  cp "$rift_bin" $out/bin/rift
  chmod +x $out/bin/rift

  # Wrap Rift to set LD_LIBRARY_PATH so libjvm.so is found
  wrapProgram $out/bin/rift \
    --prefix LD_LIBRARY_PATH : "${pkgs.openjdk}/lib/server:${pkgs.openjdk}/lib"

  # Install .desktop file
  mkdir -p $out/share/applications
  cat > $out/share/applications/rift.desktop <<EOF
[Desktop Entry]
Name=Rift
Comment=Rift 5.1.2
Exec=$out/bin/rift
Icon=rift
Terminal=false
Type=Application
Categories=Game;
EOF
  '';


  meta = with pkgs.lib; {
    description = "Rift 5.1.2";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
