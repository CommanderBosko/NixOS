{ pkgs, ... }:

{
  # Apps installed on every desktop host (flatpaks live in flatpak.nix). Host
  # environment.nix files add only their host-specific extras on top of this
  # list.

  # GVfs: userspace virtual filesystem Thunar's sidebar/GIO volume monitor
  # needs to see and auto-mount removable media (USB drives, etc.). The
  # kernel/udisks2/polkit layer already handles detection and mounting fine
  # without this (confirmed live: `udisksctl mount` works with no auth
  # prompt) — this is specifically what's missing for Thunar to notice and
  # auto-mount a drive on insertion, since Dolphin (KIO/Solid-based) never
  # needed it.
  services.gvfs.enable = true;

  # Background SMART monitoring — drive health/warnings land in the journal,
  # so no sudo is needed to check on a drive (journalctl -u smartd).
  services.smartd.enable = true;

  # Passwordless smartctl for wheel: reading SMART data needs CAP_SYS_ADMIN
  # (NVMe admin ioctl), so group membership can't replace sudo, and Claude
  # Code's shell has no TTY to type a password into. Scoped to the read-only
  # flag sets (-H/-A/-a/-x) rather than all of smartctl; the trailing `*` is
  # the device path. Resolved via the system profile path, as sudo matches
  # the real command path.
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands =
        (map (args: {
          command = "/run/current-system/sw/bin/smartctl ${args} *";
          options = [ "NOPASSWD" ];
        }) [ "-H" "-A" "-H -A" "-a" "-x" ])
        # --scan takes no device, so it needs an exact entry without the `*`.
        ++ [{
          command = "/run/current-system/sw/bin/smartctl --scan";
          options = [ "NOPASSWD" ];
        }];
    }
  ];

  # XDG portals + dconf (GTK settings) — needed by every desktop session, not
  # just SDDM's greeter.
  xdg.portal.enable = true;
  programs.dconf.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    aria2
    brave
    cava
    chromium
    cmatrix
    firefox
    freetube
    github-desktop
    gparted
    imv
    kdePackages.kate
    kitty
    megasync
    onlyoffice-desktopeditors
    pipes
    pywal # shell.nix replays its cached palette in interactive shells
    qalculate-qt
    qdirstat
    smartmontools # smartctl for SSD/HDD SMART health checks (needs sudo)
    thunar
    thunar-volman # Auto-mount + notification on removable-media insertion for Thunar
    tty-clock
    unrar # RAR backend for xarchiver; p7zip can't open RAR5/RAR7 (unfree, allowUnfree is on)
    vesktop
    vlc
    xarchiver
    zathura
  ];
}
