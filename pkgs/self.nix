final: prev:
let
  inherit (prev.stdenv.hostPlatform) system;
  inherit (final)
    inputs
    self
    lib'
    ;
  os = lib'.systemOs system;
  nixpkgsArgs = {
    inherit system;
    config = self.nixpkgsConfig;
  };
in
{
  nixpkgs = import inputs.nixpkgs nixpkgsArgs;
  stable = import (lib'.systemInput {
    inherit inputs os;
    name = "nixpkgs";
    channel = "stable";
  }) nixpkgsArgs;
  unstable = import (lib'.systemInput {
    inherit inputs os;
    name = "nixpkgs";
    channel = "unstable";
  }) nixpkgsArgs;

  inherit (self.packages.${system}) treefmt-nix;
  determinate-nix = inputs.determinate.inputs.nix.packages."${system}".default;
}
