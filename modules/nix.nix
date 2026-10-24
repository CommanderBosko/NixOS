{ ... }:

{
  # Enable unfree packages
  nixpkgs.config.allowUnfree = true;

  # TEMPORARY (added 2026-10-24): nixpkgs 99a4982ba (2026-10-16) marks pinchflat
  # with knownVulnerabilities — upstream is unmaintained, so dependency CVEs go
  # unpatched. Same 2025.9.26 build gaming already runs; the UI is only open on
  # LAN + wg0 (hosts/gaming/pinchflat.nix). REMOVE once pinchflat moves to the
  # pinchflat-ngx fork or nixpkgs drops the flag.
  nixpkgs.config.permittedInsecurePackages = [ "pinchflat-2025.9.26" ];

  # Custom packages not (yet) in nixpkgs live under pkgs/ (see pkgs/default.nix)
  # and are exposed via this overlay so any module can reach them as plain
  # pkgs.<name>, same as an upstream package.
  nixpkgs.overlays = [ (import ../pkgs) ];

  # Nix settings
  nix.settings = {
    experimental-features = [
      "flakes"
      "nix-command"
    ];

    auto-optimise-store = true;
    download-buffer-size = 1024 * 1024 * 1024; # 1 GB
  };
}
