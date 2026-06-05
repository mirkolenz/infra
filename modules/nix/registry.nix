# Pins the flake registry (self, nixpkgs, stable, unstable, pkgs) per platform
# so `nix` commands resolve the same inputs the configuration was built from.
# Applied to nixos, darwin and standalone home-manager.
{ inputs, lib', ... }:
let
  mkRegistry = os: {
    cfg.flake = inputs.self;
    nixpkgs.flake = inputs.nixpkgs;
    stable.flake = lib'.systemInput {
      inherit inputs os;
      channel = "stable";
      name = "nixpkgs";
    };
    unstable.flake = lib'.systemInput {
      inherit inputs os;
      channel = "unstable";
      name = "nixpkgs";
    };
    pkgs.flake = lib'.systemInput {
      inherit inputs os;
      channel = "unstable";
      name = "nixpkgs";
    };
  };
in
{
  flake.modules.nixos.base.nix.registry = mkRegistry "linux";
  flake.modules.darwin.base.determinateNix.registry = mkRegistry "darwin";
  flake.modules.homeManager.standalone =
    { pkgs, ... }:
    {
      nix.registry = mkRegistry (if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux");
    };
}
