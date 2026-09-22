# Option + builder for nixosConfigurations. Hosts register
# `configurations.nixos.<name>.{system,module}` (see modules/hosts/*). The builder
# is also used for the installer images.
{
  inputs,
  lib,
  config,
  withSystem,
  ...
}:
{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          system = lib.mkOption { type = lib.types.enum config.systems; };
          module = lib.mkOption { type = lib.types.deferredModule; };
        };
      }
    );
    default = { };
  };

  options.nixosSystemFor = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    readOnly = true;
    description = ''
      `nixosSystem` keyed by system, taking a list of modules and building them
      against the shared package set. Upstream `read-only.nix` derives
      `nixpkgs.{config,overlays,hostPlatform}` back from that instance
      (`nixos-hardware/apple` gates `hardware.facetimehd` on
      `nixpkgs.config.allowUnfree`) and rejects any module defining its own,
      which belong into the default overlay instead.
    '';
  };

  config = {
    nixosSystemFor = lib.genAttrs config.systems (
      system: modules:
      inputs.nixpkgs-linux-unstable.lib.nixosSystem {
        system = null;
        modules = modules ++ [
          {
            _file = ./nixos-configurations.nix;
            imports = [ "${inputs.nixpkgs-linux-unstable}/nixos/modules/misc/nixpkgs/read-only.nix" ];
            nixpkgs.pkgs = withSystem system ({ pkgs, ... }: pkgs);
          }
        ];
      }
    );

    flake.nixosConfigurations = lib.mapAttrs (
      name:
      { system, module }:
      config.nixosSystemFor.${system} [
        module
        {
          _file = ./nixos-configurations.nix;
          networking.hostName = lib.mkDefault name;
        }
      ]
    ) config.configurations.nixos;

    evalTargets.nixos = lib.mapAttrs (name: { system, ... }: {
      inherit system;
      package = config.flake.nixosConfigurations.${name}.config.system.build.toplevel;
    }) config.configurations.nixos;
  };
}
