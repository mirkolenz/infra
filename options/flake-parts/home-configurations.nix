# Generic option + builder for standalone homeConfigurations. Home targets
# register `configurations.home.<name>` (see modules/hosts/home.nix) with the
# `system` selecting the shared nixpkgs instance (see nixpkgs.nix).
{
  inputs,
  lib,
  config,
  ...
}:
{
  options.configurations.home = lib.mkOption {
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

  config.flake.homeConfigurations = lib.mapAttrs (
    name:
    { system, module }:
    let
      pkgs = config.pkgsFor.${system};
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        module
        {
          _file = ./home.nix;
          # home-manager has no `nixpkgs.pkgs`: it claims `_module.args.pkgs` at
          # the default priority, which mkForce outranks.
          # https://github.com/nix-community/home-manager/issues/4571
          _module.args.pkgs = lib.mkForce pkgs;
        }
      ];
    }
  ) config.configurations.home;

  config.evalTargets = lib.mapAttrs' (
    name:
    { system, ... }:
    lib.nameValuePair "home/${name}" {
      inherit system;
      drvPath = config.flake.homeConfigurations.${name}.activationPackage.drvPath;
    }
  ) config.configurations.home;
}
