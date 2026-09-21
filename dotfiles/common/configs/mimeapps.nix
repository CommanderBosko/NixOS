{ lib, ... }:

let
  # Handler -> the MIME types it opens. Inverted into `type = handler` below,
  # so each app's types read as one list instead of a repeated value.
  # Mimetypes verified live via `xdg-mime query filetype` and each app's own
  # .desktop MimeType= declaration, not guessed — Nix config files have no
  # dedicated mimetype and fall under text/plain, which Kate already owns.
  byApp = {
    # Code / text -> Kate
    "org.kde.kate.desktop" = [
      "text/plain"
      "text/markdown"
      "text/x-markdown"
      "application/json"
      "application/yaml"
      "application/toml"
      "text/csv"
      "text/x-log"
      "text/xml"
      "application/xml"
      "text/css"
      "text/javascript"
      "text/vnd.trolltech.linguist" # .ts (TypeScript) collides with this Qt mimetype
      "text/x-python"
      "text/x-csrc"
      "text/x-chdr"
      "text/x-c++src"
      "text/x-c++hdr"
      "text/x-go"
      "text/x-lua"
      "text/x-java"
      "text/x-kotlin"
      "text/rust"
      "application/x-php"
      "application/x-ruby"
      "application/x-shellscript"
    ];

    # Word processing documents -> OnlyOffice. Excluded from the xarchiver
    # list below even though xarchiver's own .desktop file also declares
    # these mimetypes (docx/odt are zip containers) — an earlier blind copy
    # of that list wrongly sent double-clicked .docx/.odt files to the
    # archive manager instead of OnlyOffice.
    "onlyoffice-desktopeditors.desktop" = [
      "application/vnd.oasis.opendocument.text"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    ];

    # Archives -> xarchiver (full mimetype list taken from xarchiver's own
    # .desktop file, minus the two document formats above; not
    # KDE/ksycoca-reliant, unlike Ark)
    "xarchiver.desktop" = [
      "application/epub+zip"
      "application/gzip"
      "application/java-archive"
      "application/vnd.android.app-bundle"
      "application/vnd.android.package-archive"
      "application/vnd.appimage"
      "application/vnd.bzip3"
      "application/vnd.comicbook-rar"
      "application/vnd.comicbook+zip"
      "application/vnd.debian.binary-package"
      "application/vnd.efi.iso"
      "application/vnd.ms-cab-compressed"
      "application/vnd.ms-htmlhelp"
      "application/vnd.openofficeorg.extension"
      "application/vnd.rar"
      "application/vnd.snap"
      "application/vnd.squashfs"
      "application/x-7z-compressed"
      "application/x-archive"
      "application/x-arj"
      "application/x-bzip"
      "application/x-bzip-compressed-tar"
      "application/x-bzip1"
      "application/x-bzip1-compressed-tar"
      "application/x-bzip2"
      "application/x-bzip2-compressed-tar"
      "application/x-bzip3"
      "application/x-bzip3-compressed-tar"
      "application/x-cb7"
      "application/x-cbt"
      "application/x-cd-image"
      "application/x-compress"
      "application/x-compressed-tar"
      "application/x-cpio"
      "application/x-cpio-compressed"
      "application/x-java-archive"
      "application/x-lha"
      "application/x-lrzip"
      "application/x-lrzip-compressed-tar"
      "application/x-lz4"
      "application/x-lz4-compressed-tar"
      "application/x-lzip"
      "application/x-lzip-compressed-tar"
      "application/x-lzma"
      "application/x-lzma-compressed-tar"
      "application/x-lzop"
      "application/x-rar"
      "application/x-rpm"
      "application/x-rzip"
      "application/x-rzip-compressed-tar"
      "application/x-source-rpm"
      "application/x-tar"
      "application/x-tarz"
      "application/x-tzo"
      "application/x-xpinstall"
      "application/x-xz"
      "application/x-xz-compressed-tar"
      "application/x-zip-compressed-fb2"
      "application/x-zpaq"
      "application/x-zstd-compressed-tar"
      "application/zip"
      "application/zstd"
    ];

    # PDFs -> zathura (mupdf backend)
    "org.pwmt.zathura-pdf-mupdf.desktop" = [
      "application/pdf"
      "application/oxps"
      "application/x-fictionbook"
      "application/x-mobipocket-ebook"
    ];

    # Images -> imv (full mimetype list taken from imv's own .desktop
    # file; not KDE/ksycoca-reliant, unlike Gwenview)
    "imv.desktop" = [
      "image/x-farbfeld"
      "image/tiff"
      "image/tiff-fx"
      "image/png"
      "image/x-png"
      "image/jpeg"
      "image/jpg"
      "image/pjpeg"
      "image/svg+xml"
      "image/gif"
      "image/bmp"
      "image/x-bmp"
      "image/heif"
      "image/avif"
      "image/jxl"
      "image/webp"
      "image/qoi"
    ];

    # Folders -> Thunar
    "thunar.desktop" = [ "inode/directory" ];

    # Video / audio -> VLC (full mimetype list taken from vlc's own
    # .desktop file)
    "vlc.desktop" = [
      "video/mp4"
      "video/x-m4v"
      "video/quicktime"
      "video/x-msvideo"
      "video/avi"
      "video/x-matroska"
      "video/webm"
      "video/mpeg"
      "video/mp2t"
      "video/x-ms-wmv"
      "video/x-ms-asf"
      "video/x-flv"
      "video/3gpp"
      "video/3gpp2"
      "video/ogg"
      "video/mp4v-es"
      "video/divx"
      "video/msvideo"
      "video/vnd.divx"
      "video/vnd.mpegurl"
      "video/x-anim"
      "video/x-nsv"
      "video/fli"
      "video/flv"
      "video/x-flc"
      "video/x-fli"
      "video/dv"
      "audio/mpeg"
      "audio/mp3"
      "audio/x-mp3"
      "audio/mp4"
      "audio/m4a"
      "audio/x-m4a"
      "audio/aac"
      "audio/x-aac"
      "audio/flac"
      "audio/x-flac"
      "audio/ogg"
      "audio/vorbis"
      "audio/opus"
      "audio/wav"
      "audio/x-wav"
      "audio/x-matroska"
      "audio/webm"
      "audio/midi"
      "audio/basic"
      "audio/x-ms-wma"
      "audio/x-ape"
      "audio/x-musepack"
      "audio/x-tta"
      "audio/x-wavpack"
      "x-scheme-handler/rtsp"
      "x-scheme-handler/rtp"
      "x-scheme-handler/rtmp"
      "x-scheme-handler/mms"
      "x-scheme-handler/mmsh"
      "x-scheme-handler/icy"
      "application/x-flash-video"
      "application/vnd.apple.mpegurl"
      "application/xspf+xml"
    ];

    # Torrents -> qBittorrent (mimetypes taken from its own .desktop file)
    "org.qbittorrent.qBittorrent.desktop" = [
      "application/x-bittorrent"
      "x-scheme-handler/magnet"
    ];

    "firefox.desktop" = [ "x-scheme-handler/chrome" ];

    # App-specific URL/protocol handlers, carried forward from the
    # pre-existing (unmanaged) mimeapps.list so this doesn't regress
    # working OAuth/deep-link flows. Verified each .desktop still exists
    # live before including it; "podman-desktop" and "deezer-enhanced"
    # (old flatpak id) were dropped as dead — Deezer's current flatpak
    # (dev.aunetx.deezer) self-registers the same x-scheme-handler/deezer.
    "vesktop.desktop" = [ "x-scheme-handler/discord" ];
    "freetube.desktop" = [ "x-scheme-handler/freetube" ];
    "github-desktop.desktop" = [
      "x-scheme-handler/x-github-client"
      "x-scheme-handler/x-github-desktop-auth"
    ];
    "claude-code-url-handler.desktop" = [ "x-scheme-handler/claude-cli" ];
    "r2modman.desktop" = [ "x-scheme-handler/ror2mm" ];
    "dev.aunetx.deezer.desktop" = [ "x-scheme-handler/deezer" ];
  };

  # Ordered fallback lists (first installed handler wins), which the
  # one-handler-per-type form above can't express.
  #
  # Browser (HTML files + http/https links) -> Zen Browser, matching what was
  # already live for links before this was managed; firefox and brave as
  # fallback if zen isn't available.
  browsers = {
    "text/html" = [
      "app.zen_browser.zen.desktop"
      "firefox.desktop"
      "brave-browser.desktop"
    ];
    "application/xhtml+xml" = [
      "app.zen_browser.zen.desktop"
      "firefox.desktop"
    ];
    "x-scheme-handler/http" = [
      "app.zen_browser.zen.desktop"
      "firefox.desktop"
      "brave-browser.desktop"
    ];
    "x-scheme-handler/https" = [
      "app.zen_browser.zen.desktop"
      "firefox.desktop"
      "brave-browser.desktop"
    ];
  };
in
{
  # Default applications for double-click / "Open" in Thunar (or any
  # XDG-compliant app).
  #
  # force = true on both generated files: HM's xdg.mimeApps module doesn't
  # force by default, and a real (manually-created) mimeapps.list already
  # exists on live hosts from before this was managed, which blocks
  # activation ("Existing file ... would be clobbered") without this.
  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;

  xdg.mimeApps = {
    enable = true;

    # Disjoint union: a type listed under two handlers is an eval error, not
    # one silently overriding the other.
    defaultApplications = lib.foldl' lib.attrsets.unionOfDisjoint { } (
      [ browsers ] ++ lib.mapAttrsToList (app: types: lib.genAttrs types (_: app)) byApp
    );
  };
}
