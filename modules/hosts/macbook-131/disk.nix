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
              # Skipping dm-crypt's workqueues cut its write latency to that of the SSD,
              # it had averaged 20 ms against below 1 ms on the NVMe device itself.
              settings = {
                allowDiscards = true;
                bypassWorkqueues = true;
              };
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
