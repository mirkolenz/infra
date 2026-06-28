{
  inputs,
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
    in
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config = self.nixpkgsConfig;
        overlays = [ self.overlays.default ];
      };
      packages = lib.filterAttrs (_: isAvailable) (
        pkgs.custom.flattenedPackages
        // lib.optionalAttrs (system == "aarch64-linux") {
          raspi-kernel = self.nixosConfigurations.raspi.config.boot.kernelPackages.kernel;
        }
      );
      legacyPackages = pkgs;
    };
}
