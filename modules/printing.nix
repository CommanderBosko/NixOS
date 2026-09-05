{ pkgs, ... }:

{
  services.printing = {
    enable = true;
    # hplip dropped 2026-09-04: its pyqt5 dependency fails to build against
    # python3.14 (the new default as of nixpkgs 0968519e) — sip targets ABI
    # v12, which PyQt5.QtCore doesn't support yet. Upstream nixpkgs/pyqt5
    # regression, not a config bug. Not a functional loss: the only printer
    # in use is a Canon TS9500, covered by gutenprint; hplip is HP-only.
    # Revisit if an HP printer is ever added, or once pyqt5 catches up.
    drivers = with pkgs; [ brlaser gutenprint ];
    # cups-browsed defaults CreateIPPPrinterQueues to LocalOnly (IPP-over-USB
    # only) and never auto-creates queues for real network IPP printers
    # discovered via avahi — without this, network printers show up in
    # avahi-browse/lpstat -e but never become an actual CUPS destination,
    # so print dialogs never see them.
    browsedConf = ''
      CreateIPPPrinterQueues Everywhere
    '';
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # cups-browsed's shipped unit is BindsTo=avahi-daemon.service, and at boot
  # avahi-daemon reports "active" as soon as it joins lo — before it's
  # joined the real network interface a few seconds later. If cups-browsed's
  # browse-and-create pass runs in that gap it misses the printer and never
  # retries, leaving no permanent CUPS queue until something restarts it by
  # hand. Re-trigger it once the network has actually settled.
  systemd.services.cups-browsed-fixup = {
    description = "Restart cups-browsed after network settles (avahi boot-race workaround)";
    after = [ "network-online.target" "avahi-daemon.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl try-restart cups-browsed.service";
    };
  };
}
