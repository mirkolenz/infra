# The flake's only nixvim constructor: one evaluation per system and profile,
# shared by every home (see modules/programs/neovim.nix) and by `perSystem`.
# Adding a variant is one entry in `profiles`; it becomes `packages.nixvim-<name>`.
{
  inputs,
  lib,
  config,
  ...
}:
let
  profiles = {
    default.extras.enable = true;
    minimal.extras.enable = false;
  };
in
{
  options.nixvimFor = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    readOnly = true;
    description = "Shared nixvim configurations keyed by system, one per profile.";
  };

  config = {
    nixvimFor = lib.genAttrs config.systems (
      system:
      lib.mapAttrs (
        _: features:
        inputs.nixvim.lib.evalNixvim {
          modules = [
            config.flake.modules.nixvim.default
            {
              _file = ./nixvim.nix;
              nixpkgs.pkgs = config.pkgsFor.${system};
              custom.features = features;
            }
          ];
        }
      ) profiles
    );

    nixvim.packages = {
      enable = true;
      nameFunction = name: "nixvim-${name}";
    };

    perSystem =
      { system, ... }:
      {
        nixvimConfigurations = config.nixvimFor.${system};
      };
  };
}
