# Generic option + builder for darwinConfigurations. Hosts register
# `configurations.darwin.<name>.module` (see modules/hosts/*); each becomes a
# darwinConfiguration with its own nixpkgs.hostPlatform.
{
  inputs,
  lib,
  config,
  ...
}:
{
  options.configurations.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption { type = lib.types.deferredModule; };
      }
    );
    default = { };
  };

  config.flake.darwinConfigurations = lib.mapAttrs (
    name:
    { module }:
    inputs.nix-darwin.lib.darwinSystem {
      system = null;
      modules = [
        module
        {
          _file = ./darwin.nix;
          networking.hostName = lib.mkDefault name;
        }
      ];
    }
  ) config.configurations.darwin;
}
