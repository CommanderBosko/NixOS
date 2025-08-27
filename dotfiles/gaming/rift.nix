{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "rift";
  version = "5.1.2";

  src = pkgs.fetchurl {
    url = "https://riftforeve.online/download/debian/rift_5.1.2_amd64.deb";
    sha256 = "YOUR_HASH_HERE";
  };

  buildInputs = [ pkgs.dpkg ];

  unpackPhase = ''
    mkdir -p $out
    dpkg-deb -x $src $out
  '';

  installPhase = ''
    mkdir -p $out/bin
    # Rift's binary path inside the .deb might vary, adjust as needed
    cp $out/usr/bin/rift $out/bin/
    chmod +x $out/bin/rift
  '';

  meta = with pkgs.lib; {
    description = "Rift 5.1.2";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
