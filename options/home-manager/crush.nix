{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    ;

  jsonFormat = pkgs.formats.json { };

  cfg = config.programs.crush;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.crush = {
    enable = mkEnableOption "crush";

    package = mkPackageOption pkgs "crush" { nullable = true; };

    settings = mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        Configuration written to
        {file}`$XDG_CONFIG_HOME/crush/crush.json`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    xdg.configFile."crush/crush.json" = lib.mkIf (cfg.settings != { }) {
      source = jsonFormat.generate "crush-settings.json" cfg.settings;
    };
  };
}
