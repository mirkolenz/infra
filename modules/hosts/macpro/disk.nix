{
  configurations.nixos.macpro.module = {
    fileSystems."/" = {
      device = "/dev/disk/by-label/root";
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };

    swapDevices = [ { device = "/dev/disk/by-label/swap"; } ];

    boot.loader.efi.efiSysMountPoint = "/boot";
  };
}
