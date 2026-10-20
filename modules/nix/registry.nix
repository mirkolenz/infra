# Pins the flake registry (nixpkgs, stable) so `nix` commands
# resolve the same inputs the configuration was built from.
# Applied to nixos, darwin and standalone home-manager.
# Deliberately no entry for this flake itself: pinning it would put `self.outPath`
# into every system closure, so any commit would change every host's derivation.
{ inputs, ... }:
let
  registry = {
    # the channel the configuration itself is built from
    nixpkgs.flake = inputs.nixpkgs;
    stable.flake = inputs.nixpkgs-stable;
  };
in
{
  flake.modules.nixos.base.nix.registry = registry;
  flake.modules.darwin.base.determinateNix.registry = registry;
  flake.modules.homeManager.standalone.nix.registry = registry;
}
