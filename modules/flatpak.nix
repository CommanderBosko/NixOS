{ ... }:

{
  # Flatpaks installed on every desktop host. Host environment.nix files add
  # only their host-specific extras on top of this list.
  services.flatpak = {
    enable = true;
    update.onActivation = true;

    packages = [
      "com.github.tchx84.Flatseal" # Flatseal
      "it.mijorus.gearlever" # Gear Lever
      "dev.aunetx.deezer" # Deezer
      "org.kde.digikam" # Digikam
      "app.zen_browser.zen" # Zen Browser
    ];
  };

  # Deezer's flatpak sandbox has no filesystem access to theme directories
  # and no matching GTK theme extension installed, so its libdecor-drawn
  # window titlebar can't resolve the host GTK theme (Colloid-Teal-Dark as
  # of 2026-08-09, was Sweet-Dark before) — it falls back to a plain,
  # unthemed light bar regardless of the portal's color-scheme signal
  # (niri.nix's xdg-desktop-portal-gtk fix only reaches apps that ask the
  # portal directly; it doesn't reach libdecor's own theme resolution).
  # Forcing GTK_THEME here gets it to render dark via Adwaita-dark instead
  # (verified working live, 2026-07-19) — not the actual host theme, but no
  # longer a jarring white titlebar.
  services.flatpak.overrides."dev.aunetx.deezer".Environment.GTK_THEME = "Adwaita:dark";

  # nix-flatpak's generated unit only orders After=multi-user.target, so on
  # every boot it races DNS coming up and fails once ("Could not resolve
  # hostname" for dl.flathub.org) before systemd's 60s on-failure restart
  # retries it successfully. Harmless (self-heals), but it trains you to
  # ignore a real failed-unit signal at boot — wait on network-online.target
  # instead so it only runs once network is actually usable.
  systemd.services.flatpak-managed-install = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
