# One nixpkgs instance per system, shared by every configuration and by
# `perSystem`: each `import <nixpkgs>` is a separate evaluation that nix cannot
# deduplicate.
{
  inputs,
  lib,
  lib',
  config,
  ...
}:
let
  nixpkgsArgs = {
    config = config.flake.nixpkgsConfig;
    overlays = [ config.flake.overlays.default ];
  };
in
{
  options = {
    pkgsFor = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      readOnly = true;
      description = "Shared nixpkgs instances keyed by system, carrying `nixpkgsConfig` and the default overlay.";
    };

    ownPkgsModuleFor = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      readOnly = true;
      description = ''
        Private package set, built from the same arguments as `pkgsFor`, for
        configurations whose own modules define `nixpkgs.overlays`.
      '';
    };
  };

  config = {
    pkgsFor = lib.genAttrs config.systems (
      system: import (lib'.nixpkgsInput { inherit inputs system; }) (nixpkgsArgs // { inherit system; })
    );

    ownPkgsModuleFor = lib.genAttrs config.systems (system: {
      nixpkgs = nixpkgsArgs // {
        hostPlatform = system;
      };
    });

    perSystem =
      { system, ... }:
      {
        _module.args.pkgs = config.pkgsFor.${system};
      };
  };
}
