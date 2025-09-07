{ pkgs }:

pkgs.stdenv.mkDerivation rec {
  pname = "rift";
  version = "5.1.2";

  src = pkgs.fetchurl {
    url = "https://riftforeve.online/download/debian/rift_5.1.2_amd64.deb";
    sha256 = "1af54h6j7mpaknyxydqi9aiz6g31kfwcllknhqzpv96bn2ps31lj";
  };

  buildInputs = with pkgs; [
    alsa-lib
    atk
    cairo
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk2
    gtk3
    krb5
    libdrm
    libGL
    libusb1
    libpulseaudio
    libva
    libvdpau
    mesa
    nspr
    nss
    pango
    pipewire
    SDL2
    SDL2_mixer
    udev
    vulkan-loader
    xorg.libX11
    xorg.libXau
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXdmcp
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libICE
    xorg.libXinerama
    xorg.libXrandr
    xorg.libXrender
    xorg.libSM
    xorg.libXtst
    xorg.libXt
    xwayland
    wayland
    zlib
    zulu
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
