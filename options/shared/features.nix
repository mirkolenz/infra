# Cross-cutting feature flags, shared across nixos/darwin/home. (nixvim declares
# its own withOptionals default in options/nixvim/features.nix.) Values are set
# per host/configuration; home inherits them from the host in modules/core/home.nix.
{ lib, ... }:
{
  options.custom.features = {
    withAlwaysOn = lib.mkEnableOption "always on";
    withOptionals = lib.mkEnableOption "all packages";
    withDisplay = lib.mkEnableOption "display";
  };
}
