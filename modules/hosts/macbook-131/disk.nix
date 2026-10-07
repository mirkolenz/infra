{
  configurations.nixos.macbook-131.module = {
    disko.devices.disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-APPLE_SSD_AP0256J_C08644301FFGXR4A0_1";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # settings.keyFile = "/tmp/secret.key";
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/swap" = {
                    mountpoint = "/swap";
                    mountOptions = [ "noatime" ];
                  };
                };
              };
            };
          };
        };
      };
    };

    # Managed by NixOS instead of disko so that changing `size` recreates the file.
    swapDevices = [
      {
        device = "/swap/swapfile";
        size = 8 * 1024;
      }
    ];

    boot.loader.efi.efiSysMountPoint = "/boot";
  };
}
