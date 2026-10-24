{ lib, ... }:
{
  options.custom.children = {
    online = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "AppArmor globs of the executables the children may use the network with.";
    };
    sandboxed = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "AppArmor globs of the executables that may create user namespaces for their sandbox.";
    };
    denied = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "AppArmor globs of system executables the children may not run.";
    };
  };
}
