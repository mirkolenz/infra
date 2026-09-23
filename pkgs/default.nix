{
  self,
  inputs,
  lib',
}:
final: prev:
let
  inherit (prev) lib;

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

  # by-name values keyed by a flat `<prefix>-<name>`, each with the attribute path it lives at
  entry = path: package: { inherit path package; };
  prefixed =
    prefix: path:
    lib.mapAttrs' (
      name: package: lib.nameValuePair "${prefix}-${name}" (entry (path ++ [ name ]) package)
    );
  topLevel = lib.mapAttrs (name: entry [ name ]) (lib.removeAttrs byName scopeNames);
  scoped = lib.concatMapAttrs (scope: prefixed scope [ scope ]) scopes;
  # dependencies vendored by a package via `passthru.vendored` (e.g. python libraries missing from
  # nixpkgs) are exposed flat as well, so that CI builds them and their update scripts run
  vendored = lib.concatMapAttrs (
    name: { path, package }: prefixed name (path ++ [ "vendored" ]) (package.vendored or { })
  ) (lib.filterAttrs (_: { package, ... }: lib.isDerivation package) (topLevel // scoped));
  ownPackages = lib.filterAttrs (_: { package, ... }: lib.isDerivation package) (
    topLevel // scoped // vendored
  );

  # overlay-style fragments, each `final: prev: -> attrset`, composed in the order listed below:
  # every fragment sees the preceding ones in its `prev`, so hotfixes come last and apply on top
  # of the packages the other fragments define. `ports.nix` carries long-lived platform ports,
  # `hotfixes.nix` only bugs with an upstream fix to track.
  # fragments may also define non-derivation values such as `pythonPackagesExtensions`
  overrides = lib'.importOverlays [
    ./overrides/inputs.nix
    ./overrides/ports.nix
    ./overrides/determinate.nix
    ./overrides/hotfixes.nix
  ] final prev;

  custom = {
    # flat derivations exposed via flake.packages and built in CI
    flattenedPackages =
      lib.mapAttrs (_: { package, ... }: package) ownPackages
      // lib.filterAttrs (_: lib.isDerivation) overrides;
    # attribute path of each by-name package in `flattenedPackages`, which `default.nix` hands
    # to update scripts; the overrides shadow nixpkgs packages and have no script of their own
    attrPaths = lib.mapAttrs (_: { path, ... }: path) (
      lib.removeAttrs ownPackages (lib.attrNames overrides)
    );
    # derivations with an in-tree hash, built by `update-flake` so it can fix them
    hashedPackages = lib.filterAttrs (_: lib.meta.availableOn prev.stdenv.hostPlatform) {
      inherit (final) caddy-custom;
    };
  };
in
# overlay layers, ordered low -> high precedence (mergeAttrsList lets later entries win)
lib.mergeAttrsList [

  # base overlay providing darwin packages
  (inputs.nix-darwin.overlays.default final prev)

  # channel instances + determinate-nix
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
