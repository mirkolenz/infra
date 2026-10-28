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

      # Upstream rebuilds the Broadcom drivers on every T2 Mac.
      boot.extraModulePackages = [
        drivers
        pkgs.kait2en.wireless
      ];

      boot.initrd.kernelModules = drivers.earlyModules;

      boot.blacklistedKernelModules = drivers.replacedModules;

      # Declared and checked against upstream in `kait2en/modules.nix`.
      boot.kernelParams = drivers.kernelParamsFor config.custom.apple-t2.model;
    };
}
