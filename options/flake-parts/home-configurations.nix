# Generic option + builder for standalone homeConfigurations. Home targets register
# `configurations.home.<name>` (see modules/hosts/home.nix) with the `system` used
# to select the unstable nixpkgs.
{
  inputs,
  lib,
  lib',
  config,
  ...
}:
{
  options.configurations.home = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          system = lib.mkOption { type = lib.types.str; };
          module = lib.mkOption { type = lib.types.deferredModule; };
        };
      }
    );
    default = { };
  };

  config.flake.homeConfigurations = lib.mapAttrs (
    name:
    { system, module }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import (lib'.systemInput {
        inherit inputs;
        os = lib'.systemOs system;
        channel = "unstable";
        name = "nixpkgs";
      }) { inherit system; };
      modules = [
        module
        { _file = ./home.nix; }
      ];
    }
  ) config.configurations.home;
}
