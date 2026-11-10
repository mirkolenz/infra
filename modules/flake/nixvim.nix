# The nixvim variants: `default` for every home, `extras` adding the heavy
# language tooling for homes with `custom.features.extras`, and `extras-low-memory`
# leaving out what hosts with `custom.features.lowMemory` would have to build
# (see modules/programs/neovim.nix).
{ config, ... }:
let
  inherit (config.flake.modules) nixvim;

  extras = {
    imports = [
      nixvim.default
      nixvim.extras
    ];
    custom.features.extras.enable = true;
  };
in
{
  configurations.nixvim = {
    default.module = nixvim.default;
    extras.module = extras;
    extras-low-memory.module = {
      imports = [ extras ];
      custom.features.lowMemory.enable = true;
    };
  };
}
