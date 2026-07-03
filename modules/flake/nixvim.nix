# Builds nixvimConfigurations (default + minimal) from flake.modules.nixvim.default.
{
  inputs,
  config,
  ...
}:
let
  mkNixvim =
    {
      system,
      features,
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
            source = inputs.nixpkgs;
          };
          custom.features = features;
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
    { system, ... }:
    {
      nixvimConfigurations = {
        default = mkNixvim {
          inherit system;
          features.extras.enable = true;
        };
        minimal = mkNixvim {
          inherit system;
          features.extras.enable = false;
        };
      };
    };
}
