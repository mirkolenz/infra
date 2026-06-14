# Working-tree update-script introspection for `flakectl update-pkgs`. Imports
# the repo at `root` (keeping package files editable in place) and inspects the
# derivations under `path` that carry a `passthru.updateScript`. Shipped with
# flakectl (rather than the target flake) so any attrset of derivations works
# without a bespoke attribute. Invoked as
# `nix {build,eval} -f update-scripts.nix <output> --argstr root <repo> --argstr path <attr.path>`.
{
  root,
  path,
}:
let
  pkgs = import root { };
  inherit (pkgs) lib;
  packages = lib.attrByPath (lib.splitString "." path) (throw "update path not found") pkgs;
  withScript = lib.filterAttrs (
    _: pkg: lib.isDerivation pkg && (pkg.updateScript or null) != null
  ) packages;
  # Keys match the Python `UpdateScript` dataclass for direct instantiation.
  updateScripts = lib.mapAttrs (key: pkg: {
    attr_path = pkg.updateScript.attrPath or "${path}.${key}";
    inherit (pkg) name;
    pname = lib.getName pkg;
    old_version = lib.getVersion pkg;
    command = map toString (lib.toList (pkg.updateScript.command or pkg.updateScript));
  }) withScript;
in
{
  # All derivation names under `path`; evaluating this is `update-flake`'s
  # fail-fast check that the working tree still evaluates after a lock update.
  names = lib.attrNames packages;
  # Built (not evaluated): the commands ride along as Nix string context (via
  # `toString`), so building realizes every updateScript before it runs;
  # flakectl reads the metadata back from this JSON.
  manifest = pkgs.writeText "flakectl-update-scripts.json" (lib.toJSON updateScripts);
  # Evaluated (not built) for the post-update commit summary: forces only each
  # package's version, so it realizes nothing.
  versions = lib.mapAttrs (_: entry: entry.old_version) updateScripts;
}
