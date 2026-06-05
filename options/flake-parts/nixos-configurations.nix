# Generic option + builder for nixosConfigurations. Hosts register
# `configurations.nixos.<name>.module` (see modules/hosts/*); each becomes a
# nixosConfiguration with its own nixpkgs.hostPlatform.
{
  inputs,
  lib,
  config,
  ...
}:
{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption { type = lib.types.deferredModule; };
      }
    );
    default = { };
  };

  config.flake.nixosConfigurations = lib.mapAttrs (
    name:
    { module }:
    inputs.nixpkgs-linux-unstable.lib.nixosSystem {
      system = null;
      modules = [
        module
        {
          _file = ./nixos.nix;
          networking.hostName = lib.mkDefault name;
        }
      ];
    }
  ) config.configurations.nixos;
}
