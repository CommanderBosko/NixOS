{ self, ... }:

{
  imports = [
    ./helix.nix
    ./ssh.nix
  ];

  home = {
    # Copy over dotfiles
    # Kate
    file.".config/katerc" = {
      source = "${self}/dotfiles/common/configs/katerc";
      force = true;
    };

    # Kitty
    file.".config/kitty/kitty.conf" = {
      source = "${self}/dotfiles/common/configs/kitty.conf";
      force = true;
    };
  };

  # Default applications for double-click / "Open" in Dolphin (or any
  # XDG-compliant app). Mimetypes verified live via `xdg-mime query
  # filetype` and each app's own .desktop MimeType= declaration, not
  # guessed — Nix config files have no dedicated mimetype and fall under
  # text/plain, which Kate already owns.
  #
  # force = true on both generated files: HM's xdg.mimeApps module doesn't
  # force by default, and a real (manually-created) mimeapps.list already
  # exists on live hosts from before this was managed, which blocks
  # activation ("Existing file ... would be clobbered") without this.
  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;

  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      # Code / text -> Kate
      "text/plain" = "org.kde.kate.desktop";
      "text/markdown" = "org.kde.kate.desktop";
      "text/x-markdown" = "org.kde.kate.desktop";
      "application/json" = "org.kde.kate.desktop";
      "application/yaml" = "org.kde.kate.desktop";
      "application/toml" = "org.kde.kate.desktop";
      "text/csv" = "org.kde.kate.desktop";
      "text/x-log" = "org.kde.kate.desktop";
      "text/xml" = "org.kde.kate.desktop";
      "application/xml" = "org.kde.kate.desktop";
      "text/css" = "org.kde.kate.desktop";
      "text/javascript" = "org.kde.kate.desktop";
      "text/vnd.trolltech.linguist" = "org.kde.kate.desktop"; # .ts (TypeScript) collides with this Qt mimetype
      "text/x-python" = "org.kde.kate.desktop";
      "text/x-csrc" = "org.kde.kate.desktop";
      "text/x-chdr" = "org.kde.kate.desktop";
      "text/x-c++src" = "org.kde.kate.desktop";
      "text/x-c++hdr" = "org.kde.kate.desktop";
      "text/x-go" = "org.kde.kate.desktop";
      "text/x-lua" = "org.kde.kate.desktop";
      "text/x-java" = "org.kde.kate.desktop";
      "text/x-kotlin" = "org.kde.kate.desktop";
      "text/rust" = "org.kde.kate.desktop";
      "application/x-php" = "org.kde.kate.desktop";
      "application/x-ruby" = "org.kde.kate.desktop";
      "application/x-shellscript" = "org.kde.kate.desktop";

      # Archives -> Ark (full mimetype list taken from ark's own .desktop file)
      "application/x-deb" = "org.kde.ark.desktop";
      "application/x-cd-image" = "org.kde.ark.desktop";
      "application/x-bcpio" = "org.kde.ark.desktop";
      "application/x-cpio" = "org.kde.ark.desktop";
      "application/x-cpio-compressed" = "org.kde.ark.desktop";
      "application/x-sv4cpio" = "org.kde.ark.desktop";
      "application/x-sv4crc" = "org.kde.ark.desktop";
      "application/x-rpm" = "org.kde.ark.desktop";
      "application/x-compress" = "org.kde.ark.desktop";
      "application/gzip" = "org.kde.ark.desktop";
      "application/x-bzip" = "org.kde.ark.desktop";
      "application/x-bzip2" = "org.kde.ark.desktop";
      "application/x-lzma" = "org.kde.ark.desktop";
      "application/x-xz" = "org.kde.ark.desktop";
      "application/zlib" = "org.kde.ark.desktop";
      "application/zstd" = "org.kde.ark.desktop";
      "application/x-lz4" = "org.kde.ark.desktop";
      "application/x-lzip" = "org.kde.ark.desktop";
      "application/x-lrzip" = "org.kde.ark.desktop";
      "application/x-lzop" = "org.kde.ark.desktop";
      "application/x-source-rpm" = "org.kde.ark.desktop";
      "application/vnd.debian.binary-package" = "org.kde.ark.desktop";
      "application/vnd.efi.iso" = "org.kde.ark.desktop";
      "application/vnd.ms-cab-compressed" = "org.kde.ark.desktop";
      "application/x-xar" = "org.kde.ark.desktop";
      "application/x-iso9660-appimage" = "org.kde.ark.desktop";
      "application/x-archive" = "org.kde.ark.desktop";
      "application/x-tar" = "org.kde.ark.desktop";
      "application/x-compressed-tar" = "org.kde.ark.desktop";
      "application/x-bzip-compressed-tar" = "org.kde.ark.desktop";
      "application/x-bzip2-compressed-tar" = "org.kde.ark.desktop";
      "application/x-tarz" = "org.kde.ark.desktop";
      "application/x-xz-compressed-tar" = "org.kde.ark.desktop";
      "application/x-lzma-compressed-tar" = "org.kde.ark.desktop";
      "application/x-lzip-compressed-tar" = "org.kde.ark.desktop";
      "application/x-tzo" = "org.kde.ark.desktop";
      "application/x-lrzip-compressed-tar" = "org.kde.ark.desktop";
      "application/x-lz4-compressed-tar" = "org.kde.ark.desktop";
      "application/x-zstd-compressed-tar" = "org.kde.ark.desktop";
      "application/x-7z-compressed" = "org.kde.ark.desktop";
      "application/vnd.rar" = "org.kde.ark.desktop";
      "application/zip" = "org.kde.ark.desktop";
      "application/x-java-archive" = "org.kde.ark.desktop";
      "application/x-lha" = "org.kde.ark.desktop";
      "application/x-stuffit" = "org.kde.ark.desktop";
      "application/x-arj" = "org.kde.ark.desktop";
      "application/arj" = "org.kde.ark.desktop";

      # PDFs -> Okular
      "application/pdf" = "okularApplication_pdf.desktop";
      "application/x-gzpdf" = "okularApplication_pdf.desktop";
      "application/x-bzpdf" = "okularApplication_pdf.desktop";
      "application/x-wwf" = "okularApplication_pdf.desktop";

      # Images -> Gwenview (full mimetype list taken from gwenview's own
      # .desktop file, minus inode/directory so folders stay with Dolphin)
      "image/avif" = "org.kde.gwenview.desktop";
      "image/gif" = "org.kde.gwenview.desktop";
      "image/heif" = "org.kde.gwenview.desktop";
      "image/jpeg" = "org.kde.gwenview.desktop";
      "image/jxl" = "org.kde.gwenview.desktop";
      "image/png" = "org.kde.gwenview.desktop";
      "image/bmp" = "org.kde.gwenview.desktop";
      "image/x-eps" = "org.kde.gwenview.desktop";
      "image/x-icns" = "org.kde.gwenview.desktop";
      "image/x-ico" = "org.kde.gwenview.desktop";
      "image/x-portable-bitmap" = "org.kde.gwenview.desktop";
      "image/x-portable-graymap" = "org.kde.gwenview.desktop";
      "image/x-portable-pixmap" = "org.kde.gwenview.desktop";
      "image/x-xbitmap" = "org.kde.gwenview.desktop";
      "image/x-xpixmap" = "org.kde.gwenview.desktop";
      "image/tiff" = "org.kde.gwenview.desktop";
      "image/x-psd" = "org.kde.gwenview.desktop";
      "image/x-webp" = "org.kde.gwenview.desktop";
      "image/webp" = "org.kde.gwenview.desktop";
      "image/x-tga" = "org.kde.gwenview.desktop";
      "image/x-xcf" = "org.kde.gwenview.desktop";
      "image/openraster" = "org.kde.gwenview.desktop";
      "image/svg+xml" = "org.kde.gwenview.desktop";
      "image/svg+xml-compressed" = "org.kde.gwenview.desktop";

      # Video / audio -> VLC (full mimetype list taken from vlc's own
      # .desktop file)
      "video/mp4" = "vlc.desktop";
      "video/x-m4v" = "vlc.desktop";
      "video/quicktime" = "vlc.desktop";
      "video/x-msvideo" = "vlc.desktop";
      "video/avi" = "vlc.desktop";
      "video/x-matroska" = "vlc.desktop";
      "video/webm" = "vlc.desktop";
      "video/mpeg" = "vlc.desktop";
      "video/mp2t" = "vlc.desktop";
      "video/x-ms-wmv" = "vlc.desktop";
      "video/x-ms-asf" = "vlc.desktop";
      "video/x-flv" = "vlc.desktop";
      "video/3gpp" = "vlc.desktop";
      "video/3gpp2" = "vlc.desktop";
      "video/ogg" = "vlc.desktop";
      "video/mp4v-es" = "vlc.desktop";
      "video/divx" = "vlc.desktop";
      "video/msvideo" = "vlc.desktop";
      "video/vnd.divx" = "vlc.desktop";
      "video/vnd.mpegurl" = "vlc.desktop";
      "video/x-anim" = "vlc.desktop";
      "video/x-nsv" = "vlc.desktop";
      "video/fli" = "vlc.desktop";
      "video/flv" = "vlc.desktop";
      "video/x-flc" = "vlc.desktop";
      "video/x-fli" = "vlc.desktop";
      "video/dv" = "vlc.desktop";
      "audio/mpeg" = "vlc.desktop";
      "audio/mp3" = "vlc.desktop";
      "audio/x-mp3" = "vlc.desktop";
      "audio/mp4" = "vlc.desktop";
      "audio/m4a" = "vlc.desktop";
      "audio/x-m4a" = "vlc.desktop";
      "audio/aac" = "vlc.desktop";
      "audio/x-aac" = "vlc.desktop";
      "audio/flac" = "vlc.desktop";
      "audio/x-flac" = "vlc.desktop";
      "audio/ogg" = "vlc.desktop";
      "audio/vorbis" = "vlc.desktop";
      "audio/opus" = "vlc.desktop";
      "audio/wav" = "vlc.desktop";
      "audio/x-wav" = "vlc.desktop";
      "audio/x-matroska" = "vlc.desktop";
      "audio/webm" = "vlc.desktop";
      "audio/midi" = "vlc.desktop";
      "audio/basic" = "vlc.desktop";
      "audio/x-ms-wma" = "vlc.desktop";
      "audio/x-ape" = "vlc.desktop";
      "audio/x-musepack" = "vlc.desktop";
      "audio/x-tta" = "vlc.desktop";
      "audio/x-wavpack" = "vlc.desktop";
      "x-scheme-handler/rtsp" = "vlc.desktop";
      "x-scheme-handler/rtp" = "vlc.desktop";
      "x-scheme-handler/rtmp" = "vlc.desktop";
      "x-scheme-handler/mms" = "vlc.desktop";
      "x-scheme-handler/mmsh" = "vlc.desktop";
      "x-scheme-handler/icy" = "vlc.desktop";
      "application/x-flash-video" = "vlc.desktop";
      "application/vnd.apple.mpegurl" = "vlc.desktop";
      "application/xspf+xml" = "vlc.desktop";

      # Browser (HTML files + http/https links) -> Zen Browser, matching
      # what was already live for links before this was managed; firefox
      # and brave as fallback if zen isn't available.
      "text/html" = [ "app.zen_browser.zen.desktop" "firefox.desktop" "brave-browser.desktop" ];
      "application/xhtml+xml" = [ "app.zen_browser.zen.desktop" "firefox.desktop" ];
      "x-scheme-handler/http" = [ "app.zen_browser.zen.desktop" "firefox.desktop" "brave-browser.desktop" ];
      "x-scheme-handler/https" = [ "app.zen_browser.zen.desktop" "firefox.desktop" "brave-browser.desktop" ];
      "x-scheme-handler/chrome" = "firefox.desktop";

      # App-specific URL/protocol handlers, carried forward from the
      # pre-existing (unmanaged) mimeapps.list so this doesn't regress
      # working OAuth/deep-link flows. Verified each .desktop still exists
      # live before including it; "podman-desktop" and "deezer-enhanced"
      # (old flatpak id) were dropped as dead — Deezer's current flatpak
      # (dev.aunetx.deezer) self-registers the same x-scheme-handler/deezer.
      "x-scheme-handler/discord" = "vesktop.desktop";
      "x-scheme-handler/freetube" = "freetube.desktop";
      "x-scheme-handler/x-github-client" = "github-desktop.desktop";
      "x-scheme-handler/x-github-desktop-auth" = "github-desktop.desktop";
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      "x-scheme-handler/ror2mm" = "r2modman.desktop";
      "x-scheme-handler/deezer" = "dev.aunetx.deezer.desktop";
    };
  };
}
