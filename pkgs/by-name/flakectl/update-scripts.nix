# Working-tree update-script introspection for `flakectl update-pkgs`. Imports
# the repo at `root` (keeping package files editable in place) and inspects the
# derivations under `path` that carry a `passthru.updateScript`. Shipped with
# flakectl (rather than the target flake) so any attrset of derivations works
# without a bespoke attribute. Invoked as
# `nix {build,eval} -f update-scripts.nix <output> --argstr root <repo> --argstr path <attr.path>`,
# optionally with `--argstr packages '["key", ...]'` to narrow the keys under `path`.
{
  root,
  path,
  packages ? null,
}:
let
  pkgs = import root { };
  inherit (pkgs) lib;
  all = lib.attrByPath (lib.splitString "." path) (throw "update path not found") pkgs;
  # narrowed by key alone, so the packages left out are never forced
  selected =
    if packages == null then
      all
    else
      lib.filterAttrs (key: _: lib.elem key (lib.fromJSON packages)) all;
  withScript = lib.filterAttrs (
    _: pkg: lib.isDerivation pkg && (pkg.updateScript or null) != null
  ) selected;
  # Keys match the Python `PackageMeta` dataclass for direct instantiation.
  packageMeta = lib.mapAttrs (_: pkg: {
    version = lib.getVersion pkg;
    changelog = pkg.meta.changelog or null;
  }) withScript;
  # Keys match the Python `UpdateScript` dataclass for direct instantiation.
  updateScripts = lib.mapAttrs (key: pkg: {
    attr_path = pkg.updateScript.attrPath or "${path}.${key}";
    inherit (pkg) name;
    pname = lib.getName pkg;
    old_version = packageMeta.${key}.version;
    homepage = pkg.meta.homepage or null;
    position = pkg.meta.position or null;
    command = map toString (lib.toList (pkg.updateScript.command or pkg.updateScript));
  }) withScript;
in
{
  # Built (not evaluated): the commands ride along as Nix string context (via
  # `toString`), so building realizes every updateScript before it runs;
  # flakectl reads the metadata back from this JSON.
  manifest = pkgs.writeText "flakectl-update-scripts.json" (lib.toJSON updateScripts);
  # Evaluated (not built) for the post-update commit summary: forces only each
  # package's version and changelog, so it realizes nothing.
  metadata = packageMeta;
}
