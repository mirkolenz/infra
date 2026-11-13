{
  configurations.nixos.macbook-91.module = {
    disko.devices.disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/ata-SAMSUNG_SSD_830_Series_S0VZNEAC602106";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              # zstd:1 instead of the default level 3 spares the weak CPU on writes.
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd:1"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };

    boot.loader.efi.efiSysMountPoint = "/boot";

    swapDevices = [
      {
        device = "/swapfile";
        size = 4 * 1024;
      }
    ];
  };
}
