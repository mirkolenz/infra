{
  flake.modules.nixos.apple-t2 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      drivers = pkgs.kait2en.modules;
    in
    {
      # nix build .#packages.x86_64-linux.kait2en-modules
      # A stock cached kernel, taken back out of the package so the two cannot
      # drift apart.
      boot.kernelPackages = pkgs.linuxPackagesFor drivers.kernel;

      boot.extraModulePackages = [
        drivers
        # KaiT2en carries no APFS driver, and the firmware extraction mounts
        # the macOS volume.
        config.boot.kernelPackages.apfs
      ];

      boot.initrd.kernelModules = drivers.earlyModules;

      boot.blacklistedKernelModules = drivers.replacedModules;

      boot.kernelParams = [
        # `blacklistedKernelModules` only suppresses loading by alias, which
        # leaves a module something asks for by name.
        "module_blacklist=${lib.concatStringsSep "," drivers.replacedModules}"
        # Built in, so they are reached through their initcalls instead.
        "initcall_blacklist=cmos_init,magicmouse_driver_init"
      ];
    };
}
