# Desktop dev environment: language toolchains + Nix LSP/formatter, and Godot 4
# (Mono/C#) for the Legions project. Desktop-only — the headless vpn-server
# doesn't get these.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    clang-tools
    dotnet-sdk # required for godot-mono's C# support to build/run
    gcc
    gdb
    godot-mono # C#-enabled Godot 4 build; NOT plain godot (no Mono/C# support)
    nil
    nix-init
    nixd
    nixfmt
    nodejs
    pnpm
    python3
  ];
}
