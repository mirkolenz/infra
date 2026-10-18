# Nix on hosts with little memory, where unbounded builds and evaluations
# drove the system into systemd-oomd kills.
{
  flake.modules.nixos.low-memory =
    { lib, ... }:
    {
      nix.settings = {
        max-jobs = 1;
        # Each evaluator thread keeps its own heap, the client in the terminal included.
        eval-cores = 1;
        max-substitution-jobs = 4;
        # The shared 1 GB would be per transfer.
        download-buffer-size = lib.mkForce (64 * 1024 * 1024);
      };
    };
}
