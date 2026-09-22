# Non-flake entry point: evaluates the overlaid package set from the working
# tree, the shape `nix-update` and `flakectl update-pkgs` expect from
# `import ./. { }`. See https://github.com/Mic92/nix-update/blob/main/nix_update/eval.py
{
  system ? builtins.currentSystem,
  ...
}:
let
  # `shallow=1` skips `revCount`, which a shallow clone cannot provide.
  flake = builtins.getFlake ("git+file://" + toString ./. + "?shallow=1");
  inherit (flake) inputs;
  lib' = flake.lib;
  inherit (inputs.nixpkgs) lib;

  byNameDir = toString ./pkgs/by-name;

  # Update scripts only matter to updaters, so they are adjusted here rather than
  # in the overlay the hosts use. A by-name package that builds on a nixpkgs
  # package inherits its update script, which would edit the nixpkgs source, so
  # that one is dropped. The rest are told the attribute path they live at, so
  # `nix-update` selects them directly instead of through the flattened set.
  updateScripts = _final: prev: {
    custom = prev.custom // {
      flattenedPackages = lib.mapAttrs (
        name: pkg:
        if prev.custom.attrPaths ? ${name} && lib.hasPrefix byNameDir (pkg.meta.position or "") then
          lib'.setUpdateScriptAttrPath (lib.concatStringsSep "." prev.custom.attrPaths.${name}) pkg
        else
          lib'.disableUpdateScript pkg
      ) prev.custom.flattenedPackages;
    };
  };
in
# Import `./pkgs` directly rather than the flake's store-copied
# `overlays.default`, so `meta.position` stays in the working tree and
# updateScripts can edit package files in place.
import (lib'.nixpkgsInput { inherit inputs system; }) {
  inherit system;
  overlays = [
    (import ./pkgs flake.overlayArgs)
    updateScripts
  ];
  config = flake.nixpkgsConfig;
}
