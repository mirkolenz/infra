{
  configurations.nixos.raspi.module =
    { lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      fileSystems."/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
      };

      # Adding a swap file is optional, but recommended if you use RAM-intensive applications that might OOM otherwise.
      # Size is in MiB, set to whatever you want (though note a larger value will use more disk space).
      swapDevices = [
        {
          device = "/swapfile";
          size = 8 * 1024;
        }
      ];

      nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
      powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
    };
}
