{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.disko.flakeModules.default
    inputs.nix-darwin.flakeModules.default
    inputs.home-manager.flakeModules.default
    inputs.nixvim.flakeModules.default
    inputs.treefmt-nix.flakeModule
    # flake-parts-level option declarations (e.g. configurations.{nixos,darwin,home})
    (inputs.import-tree ../../options/flake-parts)
  ];
}
