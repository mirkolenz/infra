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

    # Resume from the swapfile on the encrypted btrfs root. Because it is a file
    # (not a partition) the kernel also needs its physical offset, which only
    # exists once the 20 GiB /swapfile has been created and changes if it is ever
    # recreated. NixOS provides no option for this, so after the first rebuild run
    # the following command and add the value below, then rebuild again:
    # sudo btrfs inspect-internal map-swapfile -r /swapfile
    boot.kernelParams = [ "resume_offset=10599087" ];
    boot.resumeDevice = "/dev/mapper/cryptroot";
  };
}
