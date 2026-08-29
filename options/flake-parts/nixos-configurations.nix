# Generic option + builder for nixosConfigurations. Hosts register
# `configurations.nixos.<name>.{system,module}` (see modules/hosts/*); the system
# selects the shared package set (see nixpkgs.nix).
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
        options = {
          system = lib.mkOption { type = lib.types.enum config.systems; };
          module = lib.mkOption { type = lib.types.deferredModule; };
          sharedPkgs = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether to build against the shared package set for `system`.
              The shared path goes through upstream `read-only.nix`, which derives
              `nixpkgs.{config,overlays,hostPlatform}` back from the instance
              (`nixos-hardware/apple` gates `hardware.facetimehd` on
              `nixpkgs.config.allowUnfree`) but rejects a host defining its own
              overlays.
            '';
          };
        };
      }
    );
    default = { };
  };

  config.flake.nixosConfigurations = lib.mapAttrs (
    name:
    {
      system,
      module,
      sharedPkgs,
    }:
    inputs.nixpkgs-linux-unstable.lib.nixosSystem {
      system = null;
      modules = [
        module
        {
          _file = ./nixos.nix;
          networking.hostName = lib.mkDefault name;
        }
        (
          if sharedPkgs then
            {
              imports = [ "${inputs.nixpkgs-linux-unstable}/nixos/modules/misc/nixpkgs/read-only.nix" ];
              nixpkgs.pkgs = config.pkgsFor.${system};
            }
          else
            config.ownPkgsModuleFor.${system}
        )
      ];
    }
  ) config.configurations.nixos;
}
