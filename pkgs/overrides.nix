final: prev:
{
  llama-cpp = prev.llama-cpp.override {
    nodejs = prev.nodejs_latest;
  };
}
# packages depending on nix
// (prev.lib.genAttrs
  [
    "nix-update"
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
