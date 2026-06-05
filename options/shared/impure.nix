# `custom.impureRebuild` flag, shared across nixos/darwin/home. Nested
# home-manager inherits the host's value in modules/core/home.nix.
{ lib, ... }:
{
  options.custom.impureRebuild = lib.mkEnableOption "impure rebuild";
}
