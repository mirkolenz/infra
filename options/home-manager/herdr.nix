# Extends home-manager's `programs.herdr` with the plugin registry and the per-plugin
# configuration it does not manage.
# https://github.com/nix-community/home-manager/blob/master/modules/programs/herdr.nix
{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption;

  tomlFormat = pkgs.formats.toml { };

  cfg = config.programs.herdr;

  pluginType = lib.types.submodule (
    { name, config, ... }:
    {
      options = {
        enable = mkEnableOption "the plugin, which stays registered as disabled when off";

        package = lib.mkPackageOption pkgs [ "herdrPlugins" name ] { };

        name = mkOption {
          type = lib.types.str;
          readOnly = true;
          default = config.package.pluginId;
          description = ''
            The id herdr registers the plugin under, taken from the package. Plugin actions
            are addressed as `<name>.<action>`.
          '';
        };

        settings = mkOption {
          inherit (tomlFormat) type;
          default = { };
          example = {
            auto_open = false;
          };
          description = ''
            Configuration written to
            {file}`$XDG_CONFIG_HOME/herdr/plugins/config/<name>/config.toml`, the
            directory herdr hands the plugin as `$HERDR_PLUGIN_CONFIG_DIR`.
          '';
        };
      };
    }
  );
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.herdr.plugins = mkOption {
    type = lib.types.attrsOf pluginType;
    default = { };
    description = ''
      Plugins to register with herdr, keyed by their {var}`pkgs.herdrPlugins` name. Each
      package is built by `mkHerdrPlugin` and carries the `pluginId`, `root`, and
      `manifest` passthru attributes the registry is written from.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.plugins != { }) {
    xdg.configFile = {
      # herdr replaces every cached field from the manifest when it reads this registry,
      # so only the paths and the enabled flag matter here. Installing or toggling a
      # plugin through herdr rewrites the file over the symlink, which `force` then takes
      # back on the next activation.
      "herdr/plugins.json" = {
        force = true;
        source = pkgs.writers.writeJSON "herdr-plugins.json" (
          lib.mapAttrsToList (_: plugin: {
            plugin_id = plugin.name;
            name = plugin.package.pname;
            inherit (plugin.package) version;
            plugin_root = plugin.package.root;
            manifest_path = plugin.package.manifest;
            enabled = plugin.enable;
          }) cfg.plugins
        );
      };
    }
    // lib.concatMapAttrs (
      _: plugin:
      lib.optionalAttrs (plugin.settings != { }) {
        "herdr/plugins/config/${plugin.name}/config.toml".source =
          tomlFormat.generate "herdr-${plugin.name}-config.toml" plugin.settings;
      }
    ) cfg.plugins;
  };
}
