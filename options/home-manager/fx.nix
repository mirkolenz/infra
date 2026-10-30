# https://github.com/antonmedv/fx
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
    types
    ;

  cfg = config.programs.fx;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.fx = {
    enable = mkEnableOption "fx";

    package = mkPackageOption pkgs "fx" { nullable = true; };

    settings = mkOption {
      type = types.attrsOf (types.either types.bool types.str);
      default = { };
      example = {
        theme = "2";
        show_size = true;
      };
      description = ''
        Environment variables named `FX_<NAME>`.
        fx checks most flags for presence only, so `false` omits the variable.
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        JavaScript written to
        {file}`$XDG_CONFIG_HOME/fx/.fxrc.js`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    home.sessionVariables = lib.mapAttrs' (
      name: value: lib.nameValuePair "FX_${lib.toUpper name}" (if value == true then "1" else value)
    ) (lib.filterAttrs (_: value: value != false) cfg.settings);

    xdg.configFile."fx/.fxrc.js" = lib.mkIf (cfg.extraConfig != "") {
      text = cfg.extraConfig;
    };
  };
}
