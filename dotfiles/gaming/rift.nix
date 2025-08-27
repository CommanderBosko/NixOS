{ stdenv, fetchurl, dpkg }:

stdenv.mkDerivation rec {
  pname = "rift";
  version = "5.1.2";

  src = fetchurl {
    url = "https://riftforeve.online/download/debian/rift_5.1.2_amd64.deb";
    sha256 = "1af54h6j7mpaknyxydqi9aiz6g31kfwcllknhqzpv96bn2ps31lj";
  };

  nativeBuildInputs = [ dpkg ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    dpkg-deb -x $src $out

    mkdir -p $out/bin
    if [ -f $out/opt/rift/rift ]; then
      cp $out/opt/rift/rift $out/bin/rift
      chmod +x $out/bin/rift
    fi

    runHook postInstall
  '';

  meta = with stdenv.lib; {
    description = "Rift Intel Tool";
    homepage = "https://riftforeve.online";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
