{ pkgs, ... }:

let
  # Driverless (IPP Everywhere / URF) PPD for the home Canon TS9500, generated
  # once from the live printer and checked in (regeneration command is in the
  # file's header). A static PPD lets the queue be created at boot with no
  # network access — `model = "everywhere"` would make lpadmin query the
  # printer inside cups.service's postStart, failing CUPS itself whenever the
  # printer is off or .local resolution isn't up yet.
  canonTs9500Ppd = pkgs.runCommand "canon-ts9500-ppd" { } ''
    install -Dm644 ${./printing/canon-ts9500.ppd} $out/share/cups/model/canon-ts9500.ppd
  '';
in
{
  environment.systemPackages = with pkgs; [
    system-config-printer # GUI print-queue manager (view/cancel/pause jobs)
  ];

  services.printing = {
    enable = true;
    # hplip dropped 2026-09-04: its pyqt5 dependency fails to build against
    # python3.14 (the new default as of nixpkgs 0968519e) — sip targets ABI
    # v12, which PyQt5.QtCore doesn't support yet. Upstream nixpkgs/pyqt5
    # regression, not a config bug. Not a functional loss: the only printer
    # in use is the Canon TS9500 below; hplip is HP-only. Revisit if an HP
    # printer is ever added, or once pyqt5 catches up.
    # gutenprint is NOT the right driver for the TS9500 — its "Apollo P-2100"
    # PPD is what system-config-printer auto-picks, and jobs sent through it
    # are silently discarded by the printer while CUPS reports them completed.
    drivers = with pkgs; [ brlaser gutenprint canonTs9500Ppd ];
    # cups-browsed disabled 2026-09-23: its auto-created queue never survived
    # a reboot — at boot it restarted (via a network-online fixup) before the
    # printer was resolvable, gave up, and never retried, so the queue went
    # missing after every reboot. The Canon is declared statically below
    # instead. CUPS itself still offers any other DNS-SD printer as a
    # temporary destination in GTK/Qt print dialogs.
    browsed.enable = false;
  };

  # Permanent queue for the home printer. Named to match the DNS-SD name CUPS
  # discovers on its own, so print dialogs merge the two into one entry and
  # existing per-user lpoptions defaults keep pointing at it. dnssd:// is
  # resolved via avahi at job time (not queue-creation time), so the printer's
  # DHCP address can drift freely; if the printer is off, jobs wait in the
  # queue instead of vanishing.
  hardware.printers = {
    ensurePrinters = [
      {
        name = "Canon_TS9500_series";
        description = "Canon TS9500 series";
        deviceUri = "dnssd://Canon%20TS9500%20series._ipp._tcp.local/?uuid=00000000-0000-1000-8000-00185c12583f";
        model = "canon-ts9500.ppd";
      }
    ];
    ensureDefaultPrinter = "Canon_TS9500_series";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
