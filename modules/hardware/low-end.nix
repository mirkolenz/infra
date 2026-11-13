# Hosts with little memory or a weak CPU, where unbounded builds and evaluations
# drove the system into systemd-oomd kills.
{
  flake.modules.nixos.low-end =
    { lib, ... }:
    {
      nix.settings = {
        max-jobs = 2;
        # Each evaluator thread keeps its own heap, the client in the terminal included.
        eval-cores = 1;
        max-substitution-jobs = 4;
        # The shared 1 GB would be per transfer.
        download-buffer-size = lib.mkForce (64 * 1024 * 1024);
      };

      # Cheaper on the CPU than zstd.
      boot.zswap.compressor = "lz4";
    };
}
