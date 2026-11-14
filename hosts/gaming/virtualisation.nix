{ pkgs, ... }:

{
  # IOMMU — improves VM isolation and is required if passthrough is ever re-enabled.
  # iommu=pt improves performance for devices not passed through.
  boot = {
    kernelParams = [ "amd_iommu=on" "intel_iommu=on" "iommu=pt" ];
    # vendor-reset (AMD GPU reset-bug workaround) was dropped 2026-11-14: the
    # passthrough VM is scrapped and the module's build broke on linux-zen
    # (NixOS/nixpkgs#575192). Re-add it only if AMD passthrough is revived.
    kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" ];
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

  # Fix hardcoded path in libvirt secret encryption service
  systemd.services.virt-secret-init-encryption = {
    serviceConfig.ExecStart = [
      ""
      "${pkgs.bash}/bin/sh -c 'umask 0077 && (dd if=/dev/random status=none bs=32 count=1 | systemd-creds encrypt --name=secrets-encryption-key - /var/lib/libvirt/secrets/secrets-encryption-key)'"
    ];
  };
}
