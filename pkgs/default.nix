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
  # `<prefix>-<name>` naming shared by the two flattening mechanisms below
  flattenPrefixed = lib.concatMapAttrs (
    prefix: lib.mapAttrs' (name: lib.nameValuePair "${prefix}-${name}")
  );

  scopes = lib.getAttrs scopeNames byName;
  flattenedScopes = flattenPrefixed scopes;

  # dependencies vendored by a package via `passthru.vendored` (e.g. python libraries missing from
  # nixpkgs) are exposed flat as well, so that CI builds them and their update scripts run
  flattenedVendored = keepLocalUpdateScripts (
    flattenPrefixed (
      lib.mapAttrs (_: pkg: pkg.vendored or { }) (
        lib.filterAttrs (_: lib.isDerivation) (byName // flattenedScopes)
      )
    )
  );

  # overlay-style fragments, each `final: prev: -> attrset`, composed in the order listed below:
  # every fragment sees the preceding ones in its `prev`, so hotfixes come last and apply on top
  # of the packages the other fragments define.
  # these shadow nixpkgs packages, so their update scripts would target the wrong source
  overrides = lib.mapAttrs (_: lib'.disableUpdateScript) (
    lib'.importOverlays [
      ./overrides/inputs.nix
      ./overrides/determinate.nix
      ./overrides/hotfixes.nix
    ] final prev
  );

  custom = {
    # flat derivations exposed via flake.packages and built in CI
    flattenedPackages = lib.filterAttrs (_: lib.isDerivation) (
      byName // flattenedScopes // flattenedVendored // overrides
    );
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
