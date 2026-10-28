# Flashed as image, see the README, and grown to the card size on first boot.
{
  configurations.nixos.raspi.module =
    { lib, pkgs, ... }:
    {
      disko.devices.disk.main = {
        type = "disk";
        device = lib.mkDefault "/dev/mmcblk0";
        imageSize = "8G";
        content = {
          type = "gpt";
          partitions = {
            # The firmware loads itself, U-Boot and config.txt from the first FAT partition,
            # U-Boot then reads extlinux.conf and the kernels from the same one.
            firmware = {
              size = "1G";
              type = "0700";
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
                # zstd:1 instead of the default level 3 spares the Pi's CPU on writes.
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

      disko.imageBuilder.extraPostVM = ''
        ${lib.getExe pkgs.zstd} --rm -T0 "$out"/*.raw
      '';

      boot.growPartition = true;
      fileSystems."/".autoResize = true;

      # Managed by NixOS instead of disko so that changing `size` recreates the file.
      swapDevices = [
        {
          device = "/swap/swapfile";
          size = 8 * 1024;
        }
      ];

      # The swapfile does not fit into the image, so it is created after the root is grown.
      systemd.services.mkswap-swap-swapfile.after = [ "systemd-growfs-root.service" ];
    };
}
