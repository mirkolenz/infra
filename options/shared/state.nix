# Primary user identity and state versions, shared across nixos/darwin/home.
# Values are assigned in modules/core/identity.nix.
{ lib, ... }:
{
  options.custom.stateVersions = lib.mkOption {
    description = "State versions per configuration class.";
    type = lib.types.submodule {
      options = {
        linux = lib.mkOption { type = lib.types.str; };
        darwin = lib.mkOption { type = lib.types.int; };
        home = lib.mkOption { type = lib.types.str; };
      };
    };
  };
}
