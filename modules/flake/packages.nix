{
  self,
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
      isHydraTarget = value: lib.elem system (value.meta.hydraPlatforms or [ system ]);

      exports = lib.filterAttrs (_: isAvailable) (
        pkgs.custom.flattenedPackages
        // lib.optionalAttrs (system == "aarch64-linux") {
          raspi-kernel = self.nixosConfigurations.raspi.config.boot.kernelPackages.kernel;
        }
      );
    in
    {
      packages = exports;
      checks = lib.filterAttrs (name: value: isHydraTarget value) exports;
      legacyPackages = pkgs;
    };
}
