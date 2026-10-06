{
  configurations.nixos.raspi.module = {
    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };

    swapDevices = [
      {
        device = "/swapfile";
        size = 8 * 1024;
      }
    ];
  };
}
