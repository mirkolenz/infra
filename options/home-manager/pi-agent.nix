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

  cfg = config.programs.pi-agent;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.pi-agent = {
    enable = mkEnableOption "pi-agent";

    package = mkPackageOption pkgs "pi-agent-bin" { nullable = true; };

    settings = mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        Configuration written to
        {file}`$HOME/.pi/agent/settings.json`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    home.file.".pi/agent/settings.json" = lib.mkIf (cfg.settings != { }) {
      source = jsonFormat.generate "pi-agent-settings.json" cfg.settings;
    };
  };
}
