{ config, self, pkgs, ... }:

{
  imports = [
    ./helix.nix
    ./ssh.nix
  ];

  home = {
    # adw-gtk3 provides the actual dark theme files for the "adw-gtk3-dark"
    # GTK theme that dconf/gsettings already selects on niri hosts. Without
    # it installed, GTK3/4 apps like Thunar silently fall back to stock
    # light Adwaita since the referenced theme doesn't exist on disk.
    #
    # colloid-gtk-theme + colloid-icon-theme (teal accent) replace the
    # earlier sweet + candy-icons pairing (2026-08-09) — nixpkgs removed
    # `sweet` in its GTK2/gtk-engine-murrine end-of-life purge (see
    # sweet-theme-rollout memory / NixOS/nixpkgs#410814); Colloid's nixpkgs
    # build has no murrine dependency (confirmed via direct build), so it
    # isn't exposed to the same removal. Both packages default to building
    # only the plain/dark variant, so the teal accent needs an explicit
    # override — confirmed against real build output, not just the READMEs,
    # that this produces theme/icon folders literally named
    # "Colloid-Teal-Dark" (the exact string used by niri.nix's dconf
    # selection below). Installing them here makes the theme files
    # available on every host; theme *selection* (gtk-theme/icon-theme/
    # cursor-theme/color-scheme) is declared via dconf.settings in
    # modules/desktop-environments/niri.nix (2026-07-19), not here — this
    # file installs the packages for every host (including non-niri ones),
    # but only niri hosts assert the dconf selection.
    packages = with pkgs; [
      adw-gtk3
      (colloid-gtk-theme.override {
        themeVariants = [ "teal" ];
        colorVariants = [ "dark" ];
      })
      (colloid-icon-theme.override {
        colorVariants = [ "teal" ];
      })
    ];

    # Shared folder for natty and bosko (/srv/shared, created by
    # modules/shared-folder.nix). mkOutOfStoreSymlink points straight at the
    # real path instead of copying it into the nix store, since /srv/shared
    # is a mutable directory both users read/write at runtime.
    file."Shared".source = config.lib.file.mkOutOfStoreSymlink "/srv/shared";

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

      # Word processing documents -> OnlyOffice. Excluded from the xarchiver
      # list below even though xarchiver's own .desktop file also declares
      # these mimetypes (docx/odt are zip containers) — an earlier blind copy
      # of that list wrongly sent double-clicked .docx/.odt files to the
      # archive manager instead of OnlyOffice.
      "application/vnd.oasis.opendocument.text" = "onlyoffice-desktopeditors.desktop";
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "onlyoffice-desktopeditors.desktop";

      # Archives -> xarchiver (full mimetype list taken from xarchiver's own
      # .desktop file, minus the two document formats above; not
      # KDE/ksycoca-reliant, unlike Ark)
      "application/epub+zip" = "xarchiver.desktop";
      "application/gzip" = "xarchiver.desktop";
      "application/java-archive" = "xarchiver.desktop";
      "application/vnd.android.app-bundle" = "xarchiver.desktop";
      "application/vnd.android.package-archive" = "xarchiver.desktop";
      "application/vnd.appimage" = "xarchiver.desktop";
      "application/vnd.bzip3" = "xarchiver.desktop";
      "application/vnd.comicbook-rar" = "xarchiver.desktop";
      "application/vnd.comicbook+zip" = "xarchiver.desktop";
      "application/vnd.debian.binary-package" = "xarchiver.desktop";
      "application/vnd.efi.iso" = "xarchiver.desktop";
      "application/vnd.ms-cab-compressed" = "xarchiver.desktop";
      "application/vnd.ms-htmlhelp" = "xarchiver.desktop";
      "application/vnd.openofficeorg.extension" = "xarchiver.desktop";
      "application/vnd.rar" = "xarchiver.desktop";
      "application/vnd.snap" = "xarchiver.desktop";
      "application/vnd.squashfs" = "xarchiver.desktop";
      "application/x-7z-compressed" = "xarchiver.desktop";
      "application/x-archive" = "xarchiver.desktop";
      "application/x-arj" = "xarchiver.desktop";
      "application/x-bzip" = "xarchiver.desktop";
      "application/x-bzip-compressed-tar" = "xarchiver.desktop";
      "application/x-bzip1" = "xarchiver.desktop";
      "application/x-bzip1-compressed-tar" = "xarchiver.desktop";
      "application/x-bzip2" = "xarchiver.desktop";
      "application/x-bzip2-compressed-tar" = "xarchiver.desktop";
      "application/x-bzip3" = "xarchiver.desktop";
      "application/x-bzip3-compressed-tar" = "xarchiver.desktop";
      "application/x-cb7" = "xarchiver.desktop";
      "application/x-cbt" = "xarchiver.desktop";
      "application/x-cd-image" = "xarchiver.desktop";
      "application/x-compress" = "xarchiver.desktop";
      "application/x-compressed-tar" = "xarchiver.desktop";
      "application/x-cpio" = "xarchiver.desktop";
      "application/x-cpio-compressed" = "xarchiver.desktop";
      "application/x-java-archive" = "xarchiver.desktop";
      "application/x-lha" = "xarchiver.desktop";
      "application/x-lrzip" = "xarchiver.desktop";
      "application/x-lrzip-compressed-tar" = "xarchiver.desktop";
      "application/x-lz4" = "xarchiver.desktop";
      "application/x-lz4-compressed-tar" = "xarchiver.desktop";
      "application/x-lzip" = "xarchiver.desktop";
      "application/x-lzip-compressed-tar" = "xarchiver.desktop";
      "application/x-lzma" = "xarchiver.desktop";
      "application/x-lzma-compressed-tar" = "xarchiver.desktop";
      "application/x-lzop" = "xarchiver.desktop";
      "application/x-rar" = "xarchiver.desktop";
      "application/x-rpm" = "xarchiver.desktop";
      "application/x-rzip" = "xarchiver.desktop";
      "application/x-rzip-compressed-tar" = "xarchiver.desktop";
      "application/x-source-rpm" = "xarchiver.desktop";
      "application/x-tar" = "xarchiver.desktop";
      "application/x-tarz" = "xarchiver.desktop";
      "application/x-tzo" = "xarchiver.desktop";
      "application/x-xpinstall" = "xarchiver.desktop";
      "application/x-xz" = "xarchiver.desktop";
      "application/x-xz-compressed-tar" = "xarchiver.desktop";
      "application/x-zip-compressed-fb2" = "xarchiver.desktop";
      "application/x-zpaq" = "xarchiver.desktop";
      "application/x-zstd-compressed-tar" = "xarchiver.desktop";
      "application/zip" = "xarchiver.desktop";
      "application/zstd" = "xarchiver.desktop";

      # PDFs -> zathura (mupdf backend)
      "application/pdf" = "org.pwmt.zathura-pdf-mupdf.desktop";
      "application/oxps" = "org.pwmt.zathura-pdf-mupdf.desktop";
      "application/x-fictionbook" = "org.pwmt.zathura-pdf-mupdf.desktop";
      "application/x-mobipocket-ebook" = "org.pwmt.zathura-pdf-mupdf.desktop";

      # Images -> imv (full mimetype list taken from imv's own .desktop
      # file; not KDE/ksycoca-reliant, unlike Gwenview)
      "image/x-farbfeld" = "imv.desktop";
      "image/tiff" = "imv.desktop";
      "image/tiff-fx" = "imv.desktop";
      "image/png" = "imv.desktop";
      "image/x-png" = "imv.desktop";
      "image/jpeg" = "imv.desktop";
      "image/jpg" = "imv.desktop";
      "image/pjpeg" = "imv.desktop";
      "image/svg+xml" = "imv.desktop";
      "image/gif" = "imv.desktop";
      "image/bmp" = "imv.desktop";
      "image/x-bmp" = "imv.desktop";
      "image/heif" = "imv.desktop";
      "image/avif" = "imv.desktop";
      "image/jxl" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "image/qoi" = "imv.desktop";

      # Folders -> Thunar
      "inode/directory" = "thunar.desktop";

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

      # Torrents -> qBittorrent (mimetypes taken from its own .desktop file)
      "application/x-bittorrent" = "org.qbittorrent.qBittorrent.desktop";
      "x-scheme-handler/magnet" = "org.qbittorrent.qBittorrent.desktop";

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
