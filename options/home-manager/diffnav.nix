# https://github.com/dlvhdr/diffnav
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.programs.diffnav;

  yamlFormat = pkgs.formats.yaml { };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.diffnav = {
    enable = lib.mkEnableOption "diffnav, a git diff pager based on delta with a file tree";

    package = lib.mkPackageOption pkgs "diffnav" { nullable = true; };

    settings = lib.mkOption {
      inherit (yamlFormat) type;
      default = { };
      example = {
        ui = {
          hideHeader = true;
          sideBySide = false;
        };
      };
      description = ''
        Configuration written to {file}`$XDG_CONFIG_HOME/diffnav/config.yml`.
        See <https://github.com/dlvhdr/diffnav#configuration> for supported values.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    xdg.configFile."diffnav/config.yml" = lib.mkIf (cfg.settings != { }) {
      source = yamlFormat.generate "diffnav-config.yml" cfg.settings;
    };
  };
}
