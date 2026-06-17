# Cross-cutting feature flags, shared across all module systems
# (nixos/darwin/home/nixvim). Values are set per host/configuration; home inherits
# them from the host in modules/core/home.nix, and nixvim inherits withOptionals in
# modules/programs/neovim.nix.
{ lib, ... }:
{
  options.custom.features = {
    withAlwaysOn = lib.mkEnableOption "always on";
    withOptionals = lib.mkEnableOption "all packages";
    withDisplay = lib.mkEnableOption "display";
  };
}
