# The flake's only nixvim constructor: one evaluation per system and profile in
# `perSystem`, shared by every home through `withSystem` (see
# modules/programs/neovim.nix). Adding a variant is one entry in `profiles`; it
# becomes `packages.nixvim-<name>`.
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
  nixvim.packages = {
    enable = true;
    nameFunction = name: "nixvim-${name}";
  };

  perSystem =
    { pkgs, ... }:
    {
      nixvimConfigurations = lib.mapAttrs (
        _: features:
        inputs.nixvim.lib.evalNixvim {
          modules = [
            config.flake.modules.nixvim.default
            {
              _file = ./nixvim.nix;
              nixpkgs.pkgs = pkgs;
              custom.features = features;
            }
          ];
        }
      ) profiles;
    };
}
