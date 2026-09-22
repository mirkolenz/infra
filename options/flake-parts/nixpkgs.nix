# One nixpkgs instance per system, shared by every configuration through
# `withSystem`: each `import <nixpkgs>` is a separate evaluation that nix cannot
# deduplicate.
{
  inputs,
  lib',
  config,
  ...
}:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import (lib'.nixpkgsInput { inherit inputs system; }) {
        inherit system;
        config = config.flake.nixpkgsConfig;
        overlays = [ config.flake.overlays.default ];
      };
    };
}
