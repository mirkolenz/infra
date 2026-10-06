{
  configurations.nixos.raspi.module =
    { lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      # Cheaper on the Pi's CPU than zstd.
      boot.zswap.compressor = "lz4";

      powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
    };
}
