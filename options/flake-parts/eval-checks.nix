# Evaluation coverage for CI. `nix flake check` forces a configuration only as
# far as its toplevel derivation's attribute set, so an error reachable only from
# the builder script passes; forcing `drvPath` covers both. Each builder registers
# its own targets, which become checks that `nix flake check` forces.
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
    description = "Derivations CI forces to prove a configuration evaluates, one check each.";
  };

  # One check per target, so a run reports every configuration that fails rather
  # than stopping at the first. Forcing `drvPath` is the whole check; the result is
  # `emptyFile` so that nothing of the target enters the check's own closure, the
  # same shape as `pkgs.testers.testEqualDerivation`.
  config.perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.mapAttrs (_: target: builtins.seq target.drvPath pkgs.emptyFile) (
        lib.filterAttrs (_: target: target.system == system) config.evalTargets
      );
    };
}
