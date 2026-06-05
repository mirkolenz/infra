{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.custom.visiturl;
in
{
  options.custom.visiturl = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkEnableOption "periodically visit a URL";
            name = lib.mkOption {
              type = lib.types.str;
              default = name;
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            url = lib.mkOption {
              type = lib.types.str;
              example = "$URL";
            };
            interval = lib.mkOption {
              type = lib.types.str;
            };
            envFile = lib.mkOption {
              type = with lib.types; nullOr path;
              default = null;
            };
          };
        }
      )
    );
  };
  config = {
    systemd.timers = lib.mapAttrs' (_: entry: {
      inherit (entry) name;
      value = lib.mkIf entry.enable {
        wantedBy = [ "timers.target" ];
        description = entry.description;
        timerConfig = {
          OnBootSec = entry.interval;
          OnUnitActiveSec = entry.interval;
          Unit = "${entry.name}.service";
        };
      };
    }) cfg;
    systemd.services = lib.mapAttrs' (_: entry: {
      inherit (entry) name;
      value = lib.mkIf entry.enable {
        script = /* bash */ ''
          ${lib.getExe pkgs.wget} "${entry.url}" -O -
        '';
        serviceConfig = {
          Type = "oneshot";
          DynamicUser = true;
          EnvironmentFile = lib.mkIf (entry.envFile != null) entry.envFile;
        };
      };
    }) cfg;
  };
}
