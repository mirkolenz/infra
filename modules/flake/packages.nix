{
  self,
  lib',
  ...
}:
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
      # added past the availability filter, so that listing the checks does not
      # evaluate the raspi configuration
      checks =
        lib.filterAttrs (_: lib'.isHydraTarget) exports
        // lib.optionalAttrs (system == "aarch64-linux") {
          raspi-kernel = self.nixosConfigurations.raspi.config.boot.kernelPackages.kernel;
        };
      formatter = pkgs.treefmt-nix;
      legacyPackages = pkgs;
    };
}
