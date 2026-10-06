# https://wiki.t2linux.org/distributions/nixos/installation/
# https://github.com/nix-community/disko/blob/master/example/luks-btrfs-subvolumes.nix
let
  disk = "/dev/disk/by-id/nvme-APPLE_SSD_AP1024N_C02001700E3N9V014";
in
{
  configurations.nixos.macbook-161.module = {
    # Only manages the Linux partition (nvme0n1p3)
    # Does NOT touch macOS EFI (nvme0n1p1) or APFS (nvme0n1p2) partitions
    disko.devices.disk = {
      # Existing macOS EFI partition, shared with the macOS bootloader.
      # It is never wiped: `destroy = false` skips the destroy stage and
      # the create stage only runs mkfs if the partition has no filesystem yet.
      esp = {
        type = "disk";
        device = "${disk}-part1";
        destroy = false;
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = [ "umask=0077" ];
        };
      };
      main = {
        type = "disk";
        device = "${disk}-part3";
        destroy = false;
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

    boot.loader.efi.efiSysMountPoint = "/boot";

    swapDevices = [
      {
        device = "/swapfile";
        size = 4 * 1024;
      }
    ];
  };
}
