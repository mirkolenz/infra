final: prev:
{ }
# packages depending on nix
// (prev.lib.genAttrs
  [
    "nixos-rebuild-ng"
    "nixpkgs-review"
  ]
  (
    name:
    prev.${name}.override {
      nix = final.determinate-nix;
    }
  )
)
