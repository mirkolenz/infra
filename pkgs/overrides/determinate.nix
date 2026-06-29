final: prev:
# packages depending on nix
prev.lib.genAttrs
  [
    "nix-update"
    "nixos-rebuild-ng"
    "nixpkgs-review"
  ]
  (
    name:
    final.lib'.disableUpdateScript (
      prev.${name}.override {
        nix = final.determinate-nix;
      }
    )
  )
