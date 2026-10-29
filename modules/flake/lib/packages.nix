# Helpers for the package set and the CI around it.
{ lib, ... }:
{
  flake.lib = {
    # Whether CI builds `drv`, following Hydra's `meta.hydraPlatforms` convention.
    # flakectl's `check build` and `check flake` split `checks` by the same rule.
    isHydraTarget = drv: lib.elem drv.system (drv.meta.hydraPlatforms or [ drv.system ]);

    disableUpdateScript =
      pkg:
      pkg.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          updateScript = null;
        };
      });

    # `nix-update` resolves `attrPath` against the package set, so naming where the package
    # actually lives keeps it from selecting through a flattened set, which would force every
    # package just to answer one lookup.
    setUpdateScriptAttrPath =
      attrPath: pkg:
      pkg.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          updateScript =
            let
              script = old.passthru.updateScript or null;
            in
            if script == null then
              null
            else if lib.isAttrs script && !lib.isDerivation script then
              script // { inherit attrPath; }
            else
              {
                command = script;
                inherit attrPath;
              };
        };
      });

    # import and compose the `final: prev: -> attrset` overlay fragments of a directory
    # in the order of their names, so that each fragment sees the preceding ones in its `prev`
    importOverlays =
      dir:
      lib.composeManyExtensions (
        map import (lib.fileset.toList (lib.fileset.fileFilter (file: file.hasExt "nix") dir))
      );
  };
}
