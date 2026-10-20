# Compressed swap in RAM: zswap as a cache in front of disk swap when a host has any,
# zram otherwise, since zram in front of disk swap would invert the LRU order.
{
  flake.modules.nixos.base =
    { config, lib, ... }:
    let
      hasDiskSwap = config.swapDevices != [ ];
    in
    {
      config = lib.mkMerge [
        {
          # Kills before the kernel OOM killer would, which only acts after the system froze.
          systemd.oomd = {
            enableRootSlice = true;
            enableUserSlices = true;
          };

          boot.zswap.enable = hasDiskSwap;
        }
        (lib.mkIf (!hasDiskSwap) {
          zramSwap = {
            enable = true;
            memoryPercent = 100;
            memoryMax = 8 * 1024 * 1024 * 1024;
          };

          # Swapping to compressed RAM is cheaper than dropping the page cache,
          # and readahead only adds decompression work.
          boot.kernel.sysctl = {
            "vm.swappiness" = 180;
            "vm.page-cluster" = 0;
          };
        })
      ];
    };
}
