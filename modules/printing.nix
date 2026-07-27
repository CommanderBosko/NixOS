{ pkgs, ... }:

{
  services.printing = {
    enable = true;
    drivers = with pkgs; [ brlaser gutenprint hplip ];
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
}
