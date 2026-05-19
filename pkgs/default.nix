args@{ inputs, ... }:
final: prev:
let
  inherit (prev) lib;

  nestedScopes = [ "vimPlugins" ];

  recursiveDrvs = lib.packagesFromDirectoryRecursive {
    inherit (final) callPackage;
    directory = ./by-name;
  };

  topLevelDrvs = lib.filterAttrs (_: lib.isDerivation) recursiveDrvs;
  nestedDrvs = lib.getAttrs nestedScopes recursiveDrvs;

  flattenedDrvs = lib.concatMapAttrs (
    scopeName: lib.mapAttrs' (drvName: lib.nameValuePair "${scopeName}-${drvName}")
  ) nestedDrvs;

  custom = {
    flattenedPackages = topLevelDrvs // flattenedDrvs;
    nestedPackages = recursiveDrvs // lib.mapAttrs (name: value: prev.${name} // value) nestedDrvs;
    flakeInputs = import ./inputs.nix args final prev;
    hashedPackages = {
      inherit (final) caddy-custom;
    };
  };

in
lib.mergeAttrsList [
  (inputs.nix-darwin.overlays.default final prev)
  (import ./hotfixes.nix final prev)
  (import ./overrides.nix final prev)
  (import ./self.nix args final prev)
  custom.flakeInputs
  custom.nestedPackages
  {
    inherit inputs prev custom;
  }
]
