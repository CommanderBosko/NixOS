Run this in a terminal:

  nix repl --expr 'builtins.getFlake "path:/home/bosko/NixOS"'

Then inside the repl, bind the host config for easy access:

  cfg = nixosConfigurations.<host>.config

Example queries for <host> follow below (grouped by host applicability).

## All hosts
- `cfg.networking.hostName` — confirm which host you're looking at
- `cfg.system.stateVersion` — state version
- `builtins.attrNames cfg.services` — list all enabled service namespaces
- `cfg.environment.systemPackages` — list system packages
- `cfg.hardware.nvidia` / `cfg.programs.steam` — GPU driver / Steam config (evaluates on every host; only meaningful where the host imports the GPU / gaming module)

## Desktop hosts
- `cfg.services.displayManager.defaultSession` — active desktop session
- `cfg.home-manager.users.bosko.programs` — bosko's HM programs
- `builtins.attrNames cfg.services.flatpak` — flatpak status

## Headless hosts
- `cfg.networking.wg-quick.interfaces.wg0` — WireGuard interface config (the VPN server's wg0)
