{ lib', ... }:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    let
      isAvailable =
        value: lib.meta.availableOn { inherit system; } value && !(value.meta.broken or false);

      exports = lib.filterAttrs (_: isAvailable) pkgs.custom.flattenedPackages;
    in
    {
      packages = exports;
      checks = lib.filterAttrs (_: lib'.isHydraTarget) exports;
      formatter = pkgs.treefmt-nix;
      legacyPackages = pkgs;
    };
}
