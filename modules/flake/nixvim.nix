# The nixvim variants: `default` for every home, `extras` adding the heavy
# language tooling for homes with `custom.features.extras` (see modules/programs/neovim.nix).
{ config, ... }:
let
  inherit (config.flake.modules) nixvim;
in
{
  configurations.nixvim = {
    default.module = nixvim.default;
    extras.module = {
      imports = [
        nixvim.default
        nixvim.extras
      ];
    };
  };
}
