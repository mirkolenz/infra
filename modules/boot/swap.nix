# Compressed swap in RAM: zswap as a cache in front of disk swap when a host has any,
# zram otherwise, since zram in front of disk swap would invert the LRU order.
{
  flake.modules.nixos.base =
    { config, lib, ... }:
    let
      cfg = config.boot.zswap;
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

          # TODO: Switch to `boot.zswap.enable` once nixpkgs stops setting the `zpool` parameter,
          # which Linux removed. Until then, only its options are reused.
          boot.zswap.compressor = lib.mkDefault "zstd";
        }
        (lib.mkIf hasDiskSwap {
          boot.kernelParams = [
            "zswap.enabled=1"
            "zswap.compressor=${cfg.compressor}"
            "zswap.max_pool_percent=${toString cfg.maxPoolPercent}"
            "zswap.shrinker_enabled=${if cfg.shrinkerEnabled then "1" else "0"}"
          ];

          # A compressor built as a module is not loadable yet when zswap starts,
          # so it is set again at runtime.
          boot.kernel.sysfs.module.zswap.parameters.compressor = cfg.compressor;
        })
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
