{
  self,
  inputs,
  lib',
}:
final: prev:
let
  inherit (prev) lib;

  byNameDir = toString ./by-name;

  # a by-name file that builds on a nixpkgs package inherits its meta.position along with its
  # update script, which would then edit the nixpkgs source instead of ours
  keepLocalUpdateScripts = lib.mapAttrsRecursiveCond (value: !lib.isDerivation value) (
    _: value:
    if lib.isDerivation value && !lib.hasPrefix byNameDir (value.meta.position or "") then
      lib'.disableUpdateScript value
    else
      value
  );

  # callPackage-style packages from ./by-name; subdirectories form nested scopes (e.g. vimPlugins)
  byName = keepLocalUpdateScripts (
    lib.packagesFromDirectoryRecursive {
      inherit (final) callPackage;
      directory = ./by-name;
    }
  );
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
  # these shadow nixpkgs packages, so their update scripts would target the wrong source
  overrides = lib.mapAttrs (_: lib'.disableUpdateScript) (lib'.importOverlays ./overrides final prev);

  custom = {
    # flat derivations exposed via flake.packages and built in CI
    flattenedPackages = lib.filterAttrs (_: lib.isDerivation) (byName // flattenedScopes // overrides);
    # derivations with an in-tree hash, built by `update-flake` so it can fix them
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
  (import ./self.nix final prev)

  # overrides/ fragments
  overrides

  # by-name top-level packages
  (lib.removeAttrs byName scopeNames)

  # by-name scopes merged with nixpkgs
  (lib.mapAttrs (name: scope: (prev.${name} or { }) // scope) scopes)

  # internal passthrough (inputs / prev / custom / lib')
  {
    inherit
      self
      inputs
      prev
      custom
      lib'
      ;
  }

]
