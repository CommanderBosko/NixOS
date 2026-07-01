{ ... }:

{
  # VirtualBox host — for running a Windows guest on natalie-laptop.
  virtualisation.virtualbox.host = {
    enable = true;
    # Extension Pack: USB 2.0/3.0 passthrough, RDP, disk encryption.
    # NOTE: builds VirtualBox from source and is under Oracle's PUEL
    # (covered by nixpkgs.config.allowUnfree, set globally in nix.nix).
    enableExtensionPack = true;
  };

  # Both accounts may manage/run VirtualBox VMs.
  users.extraGroups.vboxusers.members = [ "natty" "bosko" ];

  # The Guest Additions ISO (drivers, shared folders, clipboard, display
  # integration for the Windows guest) ships with the VirtualBox host package
  # itself — mount it from the running VM via Devices → Insert Guest Additions
  # CD image. No separate package is required.
}
