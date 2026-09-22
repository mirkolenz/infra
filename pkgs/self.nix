final: prev:
let
  inherit (prev.stdenv.hostPlatform) system;
  inherit (final)
    inputs
    self
    lib'
    ;
  os = lib'.systemOs system;
  # plain channel instances without the default overlay, as a fallback when a
  # package is broken in the shared set
  nixpkgsArgs = {
    inherit system;
    config = self.nixpkgsConfig;
  };
  detnix = inputs.determinate.inputs.nix.packages."${system}".default;
in
{
  stable = import (lib'.systemInput {
    inherit inputs os;
    name = "nixpkgs";
    channel = "stable";
  }) nixpkgsArgs;
  unstable = import (lib'.nixpkgsInput { inherit inputs system; }) nixpkgsArgs;

  # the one package taken from a flake's own package set, to keep Determinate's
  # binary cache
  determinate-nix = detnix // {
    out = removeAttrs detnix.out [
      "doc"
      "man"
    ];
  };
}
