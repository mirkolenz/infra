# Option + builder for standalone homeConfigurations. Homes register
# `configurations.home.<name>.{system,module}` (see modules/hosts/home.nix).
{
  inputs,
  lib,
  config,
  withSystem,
  ...
}:
{
  options.configurations.home = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          system = lib.mkOption { type = lib.types.enum config.systems; };
          module = lib.mkOption { type = lib.types.deferredModule; };
          # whether CI evaluates the home
          check = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        };
      }
    );
    default = { };
  };

  config = {
    flake.homeConfigurations = lib.mapAttrs (
      _:
      { system, module, ... }:
      withSystem system (
        { pkgs, ... }:
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            module
            {
              _file = ./home-configurations.nix;
              # home-manager has no `nixpkgs.pkgs`: it claims `_module.args.pkgs` at
              # the default priority, which mkForce outranks.
              # https://github.com/nix-community/home-manager/issues/4571
              _module.args.pkgs = lib.mkForce pkgs;
            }
          ];
        }
      )
    ) config.configurations.home;

    evalTargets.home = lib.mapAttrs (name: { system, ... }: {
      inherit system;
      package = config.flake.homeConfigurations.${name}.activationPackage;
    }) (lib.filterAttrs (_: home: home.check) config.configurations.home);
  };
}
