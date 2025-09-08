{ config, pkgs, ... }:

{
  # Enable libvirt with QEMU/KVM
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = with pkgs; [ OVMFFull.fd ];
      };
      runAsRoot = false;
    };
  };

  # Networking
  environment.etc."libvirt/qemu/networks/default.xml".text = ''
    <network>
      <name>default</name>
      <forward mode="nat"/>
      <ip address="192.168.122.1" netmask="255.255.255.0">
        <dhcp>
          <range start="192.168.122.2" end="192.168.122.254"/>
        </dhcp>
      </ip>
    </network>
  '';

  # Enable avahi
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };


  # Packages
  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    qemu
  ];

  # Required for virt-manager auth
  security.polkit.enable = true;

  # Enable dconf for virt-manager settings
  programs.dconf.enable = true;
}
