{ pkgs, config, ... }:

let
  # Single GPU passthrough hook — stops SDDM before VM starts, rebinds nvidia after VM stops.
  # RTX 3070 PCI addresses: verify with  lspci -nn | grep -E 'VGA|Audio'
  gpuHook = pkgs.writeScript "libvirt-qemu-hook" ''
    #!/usr/bin/env bash
    GUEST="$1"
    HOOK="$2"

    [ "$GUEST" = "windows" ] || exit 0

    GPU="0000:08:00.0"
    GPU_AUDIO="0000:08:00.1"

    unbind_gpu() {
        systemctl stop sddm.service
        # Give the Wayland compositor time to release the GPU before unbinding
        sleep 3

        if [ -e "/sys/bus/pci/devices/$GPU/driver" ]; then
            echo "$GPU" > /sys/bus/pci/devices/$GPU/driver/unbind
        fi
        if [ -e "/sys/bus/pci/devices/$GPU_AUDIO/driver" ]; then
            echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind
        fi

        modprobe vfio-pci

        echo "vfio-pci" > /sys/bus/pci/devices/$GPU/driver_override
        echo "vfio-pci" > /sys/bus/pci/devices/$GPU_AUDIO/driver_override
        echo "$GPU" > /sys/bus/pci/drivers/vfio-pci/bind
        echo "$GPU_AUDIO" > /sys/bus/pci/drivers/vfio-pci/bind
    }

    rebind_gpu() {
        if [ -e "/sys/bus/pci/devices/$GPU/driver" ]; then
            echo "$GPU" > /sys/bus/pci/devices/$GPU/driver/unbind
        fi
        if [ -e "/sys/bus/pci/devices/$GPU_AUDIO/driver" ]; then
            echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind
        fi

        # RTX 30xx (Ampere) reset bug — vendor-reset clears GPU state so nvidia can re-init
        echo "$GPU" > /sys/bus/pci/drivers/vendor-reset/bind || \
            echo "vendor-reset: bind failed for $GPU" >&2

        echo "" > /sys/bus/pci/devices/$GPU/driver_override
        echo "" > /sys/bus/pci/devices/$GPU_AUDIO/driver_override
        echo "$GPU" > /sys/bus/pci/drivers_probe
        echo "$GPU_AUDIO" > /sys/bus/pci/drivers_probe

        sleep 2
        systemctl start sddm.service
    }

    case "$HOOK" in
        prepare) unbind_gpu ;;
        release) rebind_gpu ;;
    esac
  '';
in

{
  # IOMMU — required for GPU passthrough; iommu=pt improves performance for
  # devices not passed through. Both AMD and Intel flags are safe to include.
  boot = {
    kernelParams = [ "amd_iommu=on" "intel_iommu=on" "iommu=pt" ];
    # vfio modules loaded at boot so the hook can bind devices without delay.
    # vendor-reset fixes the RTX 30xx reset bug after VM shutdown.
    # kvmfr is the Looking Glass shared memory module (used once AMD host GPU is installed).
    kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "kvmfr" "vendor-reset" ];
    extraModulePackages = with config.boot.kernelPackages; [ kvmfr vendor-reset ];
    extraModprobeConfig = "options kvmfr static_size_mb=128";
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
    # GPU passthrough hook — runs as root, called by libvirtd before/after VM start/stop
    "libvirt/hooks/qemu" = {
      source = gpuHook;
      mode = "0755";
    };
  };

  # Looking Glass shared memory buffer (host side — activate once AMD host GPU is installed)
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
