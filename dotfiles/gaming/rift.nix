{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "rift";
  version = "5.1.2";

  # Fetch the .deb from the official URL
  src = pkgs.fetchurl {
    url = "https://riftforeve.online/download/debian/rift_5.1.2_amd64.deb";
    sha256 = "1af54h6j7mpaknyxydqi9aiz6g31kfwcllknhqzpv96bn2ps31lj";
  };

  buildInputs = [ pkgs.dpkg ];

  unpackPhase = "true";   # .deb will be extracted in installPhase
  buildPhase = "true";    # nothing to build

  installPhase = ''
    mkdir -p $out
    dpkg -x $src $out
  '';

  meta = with pkgs.lib; {
    description = "Rift Online Game Client";
    license = licenses.unfree;
    maintainers = [ maintainers.commanderbosko ];
  };
}
