{ config, pkgs, ... }:

{
  # Enable libvirt with QEMU/KVM
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
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

  # Fix hardcoded path in libvirt secret encryption service
  systemd.services.virt-secret-init-encryption = {
    serviceConfig.ExecStart = [
      "" # Clear existing command
      "${pkgs.bash}/bin/sh -c 'umask 0077 && (dd if=/dev/random status=none bs=32 count=1 | systemd-creds encrypt --name=secrets-encryption-key - /var/lib/libvirt/secrets/secrets-encryption-key)'"
    ];
  };
}
