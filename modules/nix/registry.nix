# Pins the flake registry (nixpkgs, stable, unstable, pkgs) per platform so `nix`
# commands resolve the same inputs the configuration was built from.
# Applied to nixos, darwin and standalone home-manager.
# Deliberately no entry for this flake itself: pinning it would put `self.outPath`
# into every system closure, so any commit would change every host's derivation.
{ inputs, lib', ... }:
let
  mkRegistry =
    os:
    let
      channelFlake =
        channel:
        lib'.systemInput {
          inherit inputs os channel;
          name = "nixpkgs";
        };
      unstable = channelFlake "unstable";
    in
    {
      nixpkgs.flake = inputs.nixpkgs;
      stable.flake = channelFlake "stable";
      unstable.flake = unstable;
      # alias for the channel the configuration itself is built from
      pkgs.flake = unstable;
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
