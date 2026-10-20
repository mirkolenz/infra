# `flake.lib`, merged from the files of modules/flake/lib. Each attribute is
# defined once, so a plain lazy attribute set is enough.
{ lib, flake-parts-lib, ... }:
{
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "Project-specific helper functions.";
    };
  };
}
