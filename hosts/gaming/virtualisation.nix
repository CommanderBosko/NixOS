{ pkgs, config, ... }:

{
  # IOMMU — improves VM isolation and is required if passthrough is ever re-enabled.
  # iommu=pt improves performance for devices not passed through.
  boot = {
    kernelParams = [ "amd_iommu=on" "intel_iommu=on" "iommu=pt" ];
    kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "vendor-reset" ];
    extraModulePackages = with config.boot.kernelPackages; [ vendor-reset ];
  };

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
      runAsRoot = false;
    };
  };

  environment.etc = {
    # NAT network for VMs
    "libvirt/qemu/networks/default.xml".text = ''
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
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  users.users.bosko.extraGroups = [ "libvirtd" "kvm" ];

  environment.variables.LIBVIRT_DEFAULT_URI = "qemu:///system";

  environment.systemPackages = with pkgs; [
    qemu
    spice
    spice-gtk
    spice-protocol
    virt-manager
    virt-viewer
  ];

  security.polkit.enable = true;
  programs.dconf.enable = true;

  # Fix hardcoded path in libvirt secret encryption service
  systemd.services.virt-secret-init-encryption = {
    serviceConfig.ExecStart = [
      ""
      "${pkgs.bash}/bin/sh -c 'umask 0077 && (dd if=/dev/random status=none bs=32 count=1 | systemd-creds encrypt --name=secrets-encryption-key - /var/lib/libvirt/secrets/secrets-encryption-key)'"
    ];
  };
}
