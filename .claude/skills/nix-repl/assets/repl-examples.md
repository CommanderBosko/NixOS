Run this in a terminal:

  nix repl --expr 'builtins.getFlake "path:/home/bosko/NixOS"'

Then inside the repl, bind the host config for easy access:

  cfg = nixosConfigurations.<host>.config

Example queries for <host>:
  cfg.networking.hostName
  cfg.environment.systemPackages
  cfg.services.openssh.enable
  cfg.home-manager.users.bosko.programs.helix.enable
  builtins.attrNames cfg.systemd.services

## All hosts
- `cfg.networking.hostName` — confirm which host you're looking at
- `cfg.system.stateVersion` — state version
- `builtins.attrNames cfg.services` — list all enabled service namespaces
- `cfg.environment.systemPackages` — list system packages

## Desktop hosts (gaming, laptop, natalie-laptop)
- `cfg.services.displayManager.defaultSession` — active desktop session
- `cfg.home-manager.users.bosko.programs` — bosko's HM programs
- `builtins.attrNames cfg.services.flatpak` — flatpak status

## gaming only
- `cfg.hardware.nvidia` — NVIDIA driver config
- `cfg.programs.steam` — Steam config

## vpn-server only
- `cfg.networking.wg-quick.interfaces.wg0` — WireGuard interface config
