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

  tomlFormat = pkgs.formats.toml { };

  cfg = config.programs.herdr;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.herdr = {
    enable = mkEnableOption "herdr";

    package = mkPackageOption pkgs "herdr" { nullable = true; };

    settings = mkOption {
      type = tomlFormat.type;
      default = { };
      description = ''
        Configuration written to
        {file}`$XDG_CONFIG_HOME/herdr/config.toml`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    xdg.configFile."herdr/config.toml" = lib.mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "herdr-config.toml" cfg.settings;
    };
  };
}
