{ config, pkgs, ... }:

{
  virtualisation.libvirtd = {
    enable = true;

    networks = {
      default = {
        # NATed virtual network
        forwardMode = "nat";
        dhcpRanges = [ { start = "192.168.122.2"; end = "192.168.122.254"; } ];
      };
    };

    qemu = {
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [ pkgs.OVMFFull.fd ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    qemu
  ];
}
