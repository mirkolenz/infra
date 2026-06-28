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
      config,
      lib,
      ...
    }:
    let
      isAvailable =
        value: lib.meta.availableOn { inherit system; } value && !(value.meta.broken or false);
      isHydraTarget = value: lib.elem system (value.meta.hydraPlatforms or [ system ]);
      # Dropped from CI checks on every system: nixvim/neovide and mistral-vibe have
      # huge build closures that are uncached for x86_64-linux and abort the job.
      ciExcludedChecks = [
        "mistral-vibe"
        "neovide"
        "nixvim-default"
        "nixvim-minimal"
      ];
    in
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config = self.nixpkgsConfig;
        overlays = [ self.overlays.default ];
      };
      checks = lib.removeAttrs (lib.filterAttrs (_: isHydraTarget) config.packages) ciExcludedChecks;
      packages = lib.filterAttrs (_: isAvailable) (
        pkgs.custom.flattenedPackages
        // lib.optionalAttrs (system == "aarch64-linux") {
          raspi-kernel = self.nixosConfigurations.raspi.config.boot.kernelPackages.kernel;
        }
      );
      legacyPackages = pkgs;
    };
}
