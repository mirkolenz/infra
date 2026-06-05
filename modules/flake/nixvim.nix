# Builds nixvimConfigurations (default + minimal) from flake.modules.nixvim.default.
{
  inputs,
  config,
  lib,
  lib',
  ...
}:
let
  mkNixvim =
    {
      system,
      withOptionals,
    }:
    inputs.nixvim.lib.evalNixvim {
      modules = [
        config.flake.modules.nixvim.default
        {
          _file = ./nixvim.nix;
          nixpkgs = {
            hostPlatform = system;
            config = config.flake.nixpkgsConfig;
            overlays = [ config.flake.overlays.default ];
            source = lib'.systemInput {
              inherit inputs;
              os = lib'.systemOs system;
              channel = "unstable";
              name = "nixpkgs";
            };
          };
          custom.features.withOptionals = withOptionals;
        }
      ];
    };
in
{
  nixvim = {
    packages = {
      enable = true;
      nameFunction = name: "nixvim-${name}";
    };
    checks = {
      enable = false;
      nameFunction = name: "nixvim-${name}";
    };
  };

  perSystem =
    {
      system,
      pkgs,
      config,
      ...
    }:
    {
      packages.neovide = pkgs.writeShellApplication {
        name = "neovide";
        text = /* bash */ ''
          ${lib.getExe pkgs.neovide} --neovim-bin ${lib.getExe config.packages.nixvim-default} "$@"
        '';
      };
      nixvimConfigurations = {
        default = mkNixvim {
          inherit system;
          withOptionals = true;
        };
        minimal = mkNixvim {
          inherit system;
          withOptionals = false;
        };
      };
    };
}
