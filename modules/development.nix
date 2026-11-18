# Desktop dev environment: language toolchains + Nix LSP/formatter, and Godot 4
# (Mono/C#) for the Legions project. Desktop-only (desktopModules, not
# commonModules).
{ pkgs, ... }:

{
  # Lets generic-linux binaries run, notably the native Claude Code build
  # (~/.local/bin, needed for Code Mode). Gaming adds its own library list in
  # gaming.nix; the two merge.
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    clang-tools
    dotnet-sdk # required for godot-mono's C# support to build/run
    gcc
    gdb
    godot-mono # C#-enabled Godot 4 build; NOT plain godot (no Mono/C# support)
    himalaya # email CLI (IMAP/SMTP), used for Gmail
    nil
    nix-init
    nixd
    nixfmt
    nodejs
    pnpm
    powershell
    python3
  ];
}
