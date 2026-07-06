{
  inputs,
  config,
  self,
  lib',
  ...
}:
{
  debug = true;
  systems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];
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
  flake = {
    overlays.default = import ../../pkgs config.flake.overlayArgs;
    nixpkgsConfig = {
      allowUnfree = true;
      nvidia.acceptLicense = true;
    };
    overlayArgs = {
      inherit self inputs lib';
    };
  };
}
