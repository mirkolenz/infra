# Primary user identity and state versions, shared across nixos/darwin/home.
# Values are assigned in modules/core/identity.nix.
{ lib, ... }:
{
  options.custom.user = lib.mkOption {
    description = "Primary user identity.";
    type = lib.types.submodule {
      options = {
        name = lib.mkOption { type = lib.types.str; };
        mail = lib.mkOption { type = lib.types.str; };
        login = lib.mkOption { type = lib.types.str; };
        sshKeys = lib.mkOption { type = lib.types.listOf lib.types.singleLineStr; };
      };
    };
  };
}
