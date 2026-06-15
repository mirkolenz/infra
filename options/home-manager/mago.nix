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

  cfg = config.programs.mago;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.mago = {
    enable = mkEnableOption "mago";

    package = mkPackageOption pkgs "mago" { nullable = true; };

    settings = mkOption {
      type = tomlFormat.type;
      default = { };
      description = ''
        Configuration written to
        {file}`$XDG_CONFIG_HOME/mago.toml`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    xdg.configFile."mago.toml" = lib.mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "mago.toml" cfg.settings;
    };
  };
}
