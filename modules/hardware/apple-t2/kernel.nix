{
  flake.modules.nixos.apple-t2 =
    { config, pkgs, ... }:
    let
      drivers = pkgs.kait2en.modules;
    in
    {
      # nix build .#.packages.x86_64-linux.kait2en-modules
      # A stock cached kernel, taken back out of the package so the two cannot
      # drift apart.
      boot.kernelPackages = drivers.linuxPackages;

      # On every T2 Mac, though only those with an Intel GPU load i915, and the
      # thunderbolt patches only act on Titan Ridge and Ice Lake controllers.
      boot.extraModulePackages = [
        drivers
        pkgs.kait2en.wireless
        pkgs.kait2en.i915
        pkgs.kait2en.thunderbolt
      ];

      boot.initrd.kernelModules = drivers.earlyModules;

      boot.blacklistedKernelModules = drivers.replacedModules;

      # Declared and checked against upstream in `kait2en/modules.nix`.
      boot.kernelParams = drivers.kernelParamsFor config.custom.apple-t2.model;
    };
}
