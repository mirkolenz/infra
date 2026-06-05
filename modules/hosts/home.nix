# Standalone home-manager deploy targets (machines without a full system config here).
# The login is derived from the part before "@" in the name.
{
  config,
  lib,
  lib',
  ...
}:
let
  inherit (config.flake.modules) homeManager;
in
{
  configurations.home =
    lib.mapAttrs
      (
        name:
        {
          system,
          uid,
          genericLinux ? true,
        }:
        {
          inherit system;
          module = {
            imports = [
              homeManager.${lib'.systemOs system}
              homeManager.standalone
            ];
            custom.user.login = lib.head (lib.splitString "@" name);
            home.uid = uid;
            targets.genericLinux.enable = genericLinux;
          };
        }
      )
      {
        "lenz@gpu.wi2.uni-trier.de" = {
          system = "x86_64-linux";
          uid = 1002;
        };
        "eifelkreis@vserv-4514" = {
          system = "x86_64-linux";
          uid = 1001;
        };
        "compute@kitei-gpu" = {
          system = "x86_64-linux";
          uid = 1001;
        };
        "mlenz@raise" = {
          system = "x86_64-linux";
          uid = 1000;
          genericLinux = false;
        };
      };
}
