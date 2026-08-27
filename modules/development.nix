# Godot 4 (Mono/C#) game dev environment — used by the Legions project
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    dotnet-sdk # required for godot-mono's C# support to build/run
    godot-mono # C#-enabled Godot 4 build; NOT plain godot (no Mono/C# support)
  ];
}
