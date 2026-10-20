final: prev:
let
  inherit (prev.stdenv.hostPlatform) system;
  inherit (final)
    inputs
    self
    ;
  detnix = inputs.determinate.inputs.nix.packages.${system}.default;
in
{
  # plain stable instance without the default overlay, as a fallback when a
  # package is broken in the shared set
  stable = import inputs.nixpkgs-stable {
    inherit system;
    config = self.nixpkgsConfig;
  };

  # the one package taken from a flake's own package set, to keep Determinate's
  # binary cache
  determinate-nix = detnix // {
    out = removeAttrs detnix.out [
      "doc"
      "man"
    ];
  };
}
