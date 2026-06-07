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
    (prev.${name}.override {
      nix = final.determinate-nix;
    }).overrideAttrs
      (oldAttrs: {
        passthru = oldAttrs.passthru // {
          updateScript = null;
        };
      })
  )
