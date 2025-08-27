{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "rift";
  version = "5.1.2";

  src = pkgs.fetchurl {
    url = "https://riftforeve.online/download/debian/rift_5.1.2_amd64.deb";
    sha256 = "1af54h6j7mpaknyxydqi9aiz6g31kfwcllknhqzpv96bn2ps31lj";
  };

  buildInputs = [ pkgs.dpkg ];

  unpackPhase = ''
    mkdir unpacked
    dpkg-deb -x $src unpacked
  '';

  installPhase = ''
    mkdir -p $out/bin
    # Automatically find the Rift binary inside the unpacked package
    rift_bin=$(find unpacked -type f -name 'rift' -executable | head -n1)
    if [ -z "$rift_bin" ]; then
      echo "Error: Rift binary not found!"
      exit 1
    fi
    cp "$rift_bin" $out/bin/
    chmod +x $out/bin/rift
  '';

  meta = with pkgs.lib; {
    description = "Rift 5.1.2";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
