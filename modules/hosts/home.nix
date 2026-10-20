# Standalone home-manager deploy targets (machines without a full system config here).
# The login is derived from the part before "@" in the name.
{ config, lib, ... }:
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
          genericLinux ? false,
          unattended ? false,
          check ? false,
        }:
        {
          inherit system check;
          module = {
            imports = [
              (if lib.elem system lib.platforms.darwin then homeManager.darwin else homeManager.linux)
              homeManager.standalone
            ];
            custom.user.login = lib.head (lib.splitString "@" name);
            custom.features.unattended.enable = unattended;
            home.uid = uid;
            targets.genericLinux.enable = genericLinux;
          };
        }
      )
      {
        # canonical homes checked by CI, the others differ from them only in
        # login and uid
        "mlenz@generic" = {
          system = "x86_64-linux";
          uid = 1000;
          genericLinux = true;
          unattended = true;
          check = true;
        };
        "mlenz@nixos" = {
          system = "x86_64-linux";
          uid = 1000;
          unattended = true;
          check = true;
        };
        "lenz@gpu.wi2.uni-trier.de" = {
          system = "x86_64-linux";
          uid = 1002;
          genericLinux = true;
          unattended = true;
        };
        "eifelkreis@vserv-4514" = {
          system = "x86_64-linux";
          uid = 1001;
          genericLinux = true;
          unattended = true;
        };
        "compute@kitei-gpu" = {
          system = "x86_64-linux";
          uid = 1001;
          genericLinux = true;
          unattended = true;
        };
        "mlenz@raise" = {
          system = "x86_64-linux";
          uid = 1000;
          unattended = true;
        };
        "mlenz@loki" = {
          system = "x86_64-linux";
          uid = 1000;
          genericLinux = true;
          unattended = true;
        };
      };
}
