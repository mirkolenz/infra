# Evaluation coverage for CI.
# `nix flake check` forces a configuration only as far as its toplevel derivation's
# attribute set, so an error reachable only from the builder script passes.
# Forcing `drvPath` covers both.
{ lib, config, ... }:
{
  options.evalTargets = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          system = lib.mkOption { type = lib.types.enum config.systems; };
          drvPath = lib.mkOption { type = lib.types.str; };
        };
      }
    );
    default = { };
    description = "Derivations CI forces when constructing checks for their system.";
  };

  config.perSystem =
    { system, ... }:
    {
      checks = builtins.deepSeq (
        lib.mapAttrs (_: target: target.drvPath) (
          lib.filterAttrs (_: target: target.system == system) config.evalTargets
        )
      ) { };
    };
}
