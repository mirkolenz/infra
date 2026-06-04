{
  lib',
  inputs,
  self,
  ...
}:
{
  imports = lib'.flocken.getModules ./.;

  debug = true;
  systems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];

  perSystem =
    {
      pkgs,
      system,
      config,
      lib,
      ...
    }:
    let
      isAvailable =
        value: lib.meta.availableOn { inherit system; } value && !(value.meta.broken or false);
      isHydraTarget = value: lib.elem system (value.meta.hydraPlatforms or [ system ]);
    in
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config = self.nixpkgsConfig;
        overlays = [ self.overlays.default ];
      };
      checks = lib.filterAttrs (_: isHydraTarget) config.packages;
      packages = lib.filterAttrs (_: isAvailable) (
        pkgs.custom.flattenedPackages
        // lib.optionalAttrs (system == "aarch64-linux") {
          raspi-kernel = self.nixosConfigurations.raspi.config.boot.kernelPackages.kernel;
        }
      );
      legacyPackages = pkgs;
    };
  flake = {
    lib = lib';
    overlays.default = import ../pkgs self.overlayArgs;
    nixpkgsConfig = {
      allowUnfree = true;
      nvidia.acceptLicense = true;
    };
    overlayArgs = {
      inherit
        self
        inputs
        lib'
        ;
    };
  };
}
