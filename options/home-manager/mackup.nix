{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.custom.mackup;
  kvDefault = lib.generators.mkKeyValueDefault { } "=";
  iniFormat = pkgs.formats.ini {
    mkKeyValue = (k: v: if v == null then k else kvDefault k v);
  };
  mkList = v: lib.genAttrs v (_: null);
  allAppNames = cfg.builtinApps ++ (lib.attrNames cfg.customApps);
in
{
  options.custom.mackup = {
    enable = lib.mkEnableOption "Mackup";
    package = lib.mkPackageOption pkgs "mackup" { nullable = true; };
    settings = lib.mkOption {
      type = with lib.types; attrsOf anything;
      description = "Settings for Mackup.";
      default = { };
      example = {
        storage.engine = "icloud";
      };
    };
    builtinApps = lib.mkOption {
      type = with lib.types; listOf str;
      description = "Built-in applications to sync.";
      default = [ ];
    };
    customApps = lib.mkOption {
      type = with lib.types; attrsOf anything;
      description = "Custom applications to sync.";
      default = { };
    };
  };
  config = lib.mkIf cfg.enable {
    home.file = {
      ".mackup.cfg".source = iniFormat.generate "mackup-config.cfg" (
        cfg.settings // { applications_to_sync = mkList allAppNames; }
      );
    }
    // (lib.mapAttrs' (name: value: {
      name = ".mackup/${name}.cfg";
      value = {
        source = iniFormat.generate "mackup-config-${name}.cfg" value;
      };
    }) cfg.customApps);
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];
  };
}
