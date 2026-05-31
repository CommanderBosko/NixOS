{ pkgs, config, ... }:

{
  # IOMMU — required for GPU passthrough; iommu=pt improves performance for
  # devices not passed through. Both AMD and Intel flags are safe to include.
  # To bind a GPU: append "vfio-pci.ids=XXXX:XXXX,XXXX:XXXX" to kernelParams.
  # Find IDs: lspci -nn | grep -E 'VGA|Audio'
  boot = {
    kernelParams = [ "amd_iommu=on" "intel_iommu=on" "iommu=pt" ];
    # Load VFIO before GPU drivers so vfio-pci can claim passthrough devices first
    initrd.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" ];
    kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "kvmfr" ];
    # kvmfr: Looking Glass shared memory kernel module
    extraModulePackages = [ config.boot.kernelPackages.kvmfr ];
    extraModprobeConfig = "options kvmfr static_size_mb=128";
  };

  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull ]; # Includes Secure Boot — required for Windows 11
        };
        runAsRoot = false;
      };
    };
  };

  # NAT network for VMs
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

  # Looking Glass shared memory buffer (host side)
  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 bosko kvm -"
  ];

  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
    };
    udev.extraRules = ''
      SUBSYSTEM=="kvmfr", OWNER="root", GROUP="kvm", MODE="0660"
    '';
  };

  users.users.bosko.extraGroups = [ "libvirtd" "kvm" ];

  environment.systemPackages = with pkgs; [
    looking-glass-client
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
