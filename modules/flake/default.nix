{
  inputs,
  config,
  lib,
  lib',
  ...
}:
{
  systems = import inputs.systems;
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.disko.flakeModules.default
    inputs.nix-darwin.flakeModules.default
    inputs.home-manager.flakeModules.default
    inputs.nixvim.flakeModules.default
    # flake-parts-level option declarations (e.g. configurations.{nixos,darwin,home})
    (inputs.import-tree ../../options/flake-parts)
  ];
  flake = {
    overlays.default = import ../../pkgs config.flake.overlayArgs;
    nixpkgsConfig = {
      allowUnfree = true;
      nvidia.acceptLicense = true;
      # Zotero 10 embeds Gecko from ESR 140, which reached end-of-life on 2026-10-13.
      allowInsecurePredicate = pkg: lib.getName pkg == "firefox-esr-140-bin-unwrapped";
    };
    overlayArgs = {
      inherit inputs lib';
    };
  };
}
