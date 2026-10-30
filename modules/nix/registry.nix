# Pins nixpkgs in the flake registry to the inputs the configuration was built from,
# and adds this flake's package set at its latest commit.
# Applied to nixos, darwin and standalone home-manager.
{ inputs, ... }:
let
  registry = {
    # the channel the configuration itself is built from
    nixpkgs.flake = inputs.nixpkgs;
    infra.to = {
      type = "github";
      owner = "mirkolenz";
      repo = "infra";
    };
  };
in
{
  flake.modules.nixos.base.nix.registry = registry;
  flake.modules.darwin.base.determinateNix.registry = registry;
  flake.modules.homeManager.standalone.nix.registry = registry;
}
