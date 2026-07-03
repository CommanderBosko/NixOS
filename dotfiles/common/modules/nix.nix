{ ... }:

{
  # Enable unfree packages
  nixpkgs.config.allowUnfree = true;

  # TEMPORARY (added 2026-07-02): vesktop pins pnpm_10_29_2 as its build tool,
  # and that pnpm version is marked insecure (CVE-2026-48995 et al. — pnpm CLI
  # vulns, not vesktop runtime code). nixpkgs master already switched vesktop
  # to pnpm_10 (commit 4b3d28a4, 2026-06-29); REMOVE this waiver once
  # nixos-unstable includes that commit and eval succeeds without it.
  nixpkgs.config.permittedInsecurePackages = [
    "pnpm-10.29.2"
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
