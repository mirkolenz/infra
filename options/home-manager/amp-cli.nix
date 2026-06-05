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

  cfg = config.programs.amp-cli;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.amp-cli = {
    enable = mkEnableOption "amp-cli";

    package = mkPackageOption pkgs "amp-cli" { nullable = true; };

    settings = mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        Configuration written to
        {file}`$XDG_CONFIG_HOME/amp/settings.json`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    xdg.configFile."amp/settings.json" = lib.mkIf (cfg.settings != { }) {
      source = jsonFormat.generate "amp-settings.json" cfg.settings;
    };
  };
}
