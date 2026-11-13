{
  configurations.nixos.macbook-113.module = {
    disko.devices.disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/ata-APPLE_SSD_SM0512F_S1K5NYAF768745";
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
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # settings.keyFile = "/tmp/secret.key";
              # dm-crypt's workqueues only add latency on SSDs.
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
        # >= RAM (16 GiB) so it can hold a hibernation image (see hibernate.nix).
        size = 20 * 1024;
      }
    ];

    # Resume needs no offset or device here: the systemd initrd reads the
    # HibernateLocation EFI variable that systemd writes when it hibernates.
  };
}
