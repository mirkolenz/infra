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
            source = inputs.nixpkgs;
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
    { system, ... }:
    {
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
