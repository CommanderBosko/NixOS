{ ... }:

{
  # Enable unfree packages
  nixpkgs.config.allowUnfree = true;

  # TEMPORARY (added 2026-07-16): vesktop wraps its binary around the bundled
  # electron-40.10.5 at runtime (postFixup), and that Electron build is marked
  # insecure (EOL — no further upstream security patches). This accepts running
  # an EOL Chromium/V8 engine for vesktop's Discord-content rendering (links,
  # embeds, gifs) until nixpkgs bumps vesktop to a non-EOL Electron. REMOVE this
  # waiver once a `nix flake update` deep-evals cleanly without it.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
  ];

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
