# The flake's only nixvim constructor: one evaluation per system in `perSystem`,
# shared by every home through `withSystem` (see modules/programs/neovim.nix).
# It becomes `packages.nixvim-default`.
{
  inputs,
  config,
  ...
}:
{
  nixvim.packages = {
    enable = true;
    nameFunction = name: "nixvim-${name}";
  };

  perSystem =
    { pkgs, ... }:
    {
      nixvimConfigurations.default = inputs.nixvim.lib.evalNixvim {
        modules = [
          config.flake.modules.nixvim.default
          {
            _file = ./nixvim.nix;
            nixpkgs.pkgs = pkgs;
          }
        ];
      };
    };
}
