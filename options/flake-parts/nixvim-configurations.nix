# Option + builder for nixvimConfigurations. Variants register
# `configurations.nixvim.<name>.module` (see modules/flake/nixvim.nix). Each one is
# evaluated once per system in `perSystem` and becomes `packages.nixvim-<name>`,
# shared by every home through `withSystem` (see modules/programs/neovim.nix).
{
  inputs,
  lib,
  config,
  ...
}:
{
  options.configurations.nixvim = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          module = lib.mkOption { type = lib.types.deferredModule; };
        };
      }
    );
    default = { };
  };

  config = {
    nixvim.packages = {
      enable = true;
      nameFunction = name: "nixvim-${name}";
    };

    perSystem =
      { pkgs, ... }:
      {
        nixvimConfigurations = lib.mapAttrs (
          _:
          { module }:
          inputs.nixvim.lib.evalNixvim {
            modules = [
              module
              {
                _file = ./nixvim-configurations.nix;
                nixpkgs.pkgs = pkgs;
              }
            ];
          }
        ) config.configurations.nixvim;
      };
  };
}
