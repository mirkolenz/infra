{
  inputs,
  self,
  config,
  lib',
  ...
}:
{
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
