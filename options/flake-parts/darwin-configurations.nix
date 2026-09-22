# Option + builder for darwinConfigurations. Hosts register
# `configurations.darwin.<name>.{system,module}` (see modules/hosts/*); `system`
# is the only source of truth, as `nixpkgs.pkgs` disables the platform assertion.
{
  inputs,
  lib,
  lib',
  config,
  withSystem,
  ...
}:
{
  options.configurations.darwin = lib.mkOption {
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

  config = {
    flake.darwinConfigurations = lib.mapAttrs (
      name:
      { system, module }:
      inputs.nix-darwin.lib.darwinSystem {
        system = null;
        modules = [
          module
          {
            _file = ./darwin-configurations.nix;
            networking.hostName = lib.mkDefault name;
            nixpkgs = {
              pkgs = withSystem system ({ pkgs, ... }: pkgs);
              # nix-darwin ignores the supplied instance when resolving
              # `system.nixpkgsRevision` and reads this input instead.
              source = lib'.nixpkgsInput { inherit inputs system; };
            };
          }
        ];
      }
    ) config.configurations.darwin;

    evalTargets.darwin = lib.mapAttrs (name: { system, ... }: {
      inherit system;
      package = config.flake.darwinConfigurations.${name}.config.system.build.toplevel;
    }) config.configurations.darwin;
  };
}
