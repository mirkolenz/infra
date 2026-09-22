# Evaluation coverage for configurations.
# `nix flake check` forces a configuration only as far as its toplevel derivation's
# attribute set, so an error reachable only from the builder script passes.
# Each target therefore becomes an empty file whose text forces the target's
# `drvPath`: evaluating the check forces the whole configuration, while building
# it never builds the configuration, and the file references nothing. Only the
# text depends on the target, so reading `system` or `meta` stays cheap. An empty
# `hydraPlatforms` keeps CI from building or pushing them (see `lib'.isHydraTarget`).
{ lib, config, ... }:
let
  mkCheck =
    pkgs: name: target:
    lib.nameValuePair name (
      pkgs.writeTextFile {
        name = lib.strings.sanitizeDerivationName name;
        text = lib.seq target.package.drvPath "";
        meta.hydraPlatforms = [ ];
      }
    );
in
{
  options.evalTargets = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.lazyAttrsOf (
        lib.types.submodule {
          options = {
            system = lib.mkOption { type = lib.types.enum config.systems; };
            package = lib.mkOption { type = lib.types.package; };
          };
        }
      )
    );
    default = { };
    description = "Derivations evaluated as checks for their system, keyed by class and name.";
  };

  config.perSystem =
    { system, pkgs, ... }:
    {
      checks = lib.concatMapAttrs (
        class: targets:
        lib.mapAttrs' (name: mkCheck pkgs "eval-${class}-${name}") (
          lib.filterAttrs (_: target: target.system == system) targets
        )
      ) config.evalTargets;
    };
}
