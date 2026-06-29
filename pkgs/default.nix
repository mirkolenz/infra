args@{ inputs, lib', ... }:
final: prev:
let
  inherit (prev) lib;
  inherit (prev.stdenv.hostPlatform) system;

  # callPackage-style packages from ./by-name; subdirectories form nested scopes (e.g. vimPlugins)
  byName = lib.packagesFromDirectoryRecursive {
    inherit (final) callPackage;
    directory = ./by-name;
  };
  # a subdirectory is a scope only when it has no package.nix (matching packagesFromDirectoryRecursive)
  scopeNames = lib.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && !lib.pathExists (./by-name + "/${name}/package.nix")
    ) (lib.readDir ./by-name)
  );
  scopes = lib.getAttrs scopeNames byName;
  flattenedScopes = lib.concatMapAttrs (
    scopeName: lib.mapAttrs' (drvName: lib.nameValuePair "${scopeName}-${drvName}")
  ) scopes;

  # overlay-style fragments from ./overrides, each `final: prev: -> attrset`
  overrides = lib'.importOverlays ./overrides final prev;

  custom = {
    # flat derivations exposed via flake.packages and built in CI
    flattenedPackages = lib.filterAttrs (_: lib.isDerivation) (byName // flattenedScopes // overrides);
    hashedPackages = {
      inherit (final) caddy-custom;
    };
  };
in
# overlay layers, ordered low -> high precedence (mergeAttrsList lets later entries win)
lib.mergeAttrsList [

  # base overlay providing darwin packages
  (inputs.nix-darwin.overlays.default final prev)

  # pinned nixpkgs instances + determinate-nix
  (import ./self.nix (args // { inherit system; }))

  # overrides/ fragments
  overrides

  # by-name top-level packages
  (lib.removeAttrs byName scopeNames)

  # by-name scopes merged with nixpkgs
  (lib.mapAttrs (name: scope: (prev.${name} or { }) // scope) scopes)

  # internal passthrough (inputs / prev / custom / lib')
  {
    inherit
      inputs
      prev
      custom
      lib'
      ;
  }

]
