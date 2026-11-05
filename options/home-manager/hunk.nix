# https://github.com/modem-dev/hunk
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.programs.hunk;

  tomlFormat = pkgs.formats.toml { };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.hunk = {
    enable = lib.mkEnableOption "hunk, a terminal diff viewer for agentic changesets";

    package = lib.mkPackageOption pkgs "hunk" { nullable = true; };

    settings = lib.mkOption {
      inherit (tomlFormat) type;
      default = { };
      example = {
        theme = "monokai";
        vcs.watch = true;
      };
      description = ''
        Configuration written to {file}`$XDG_CONFIG_HOME/hunk/config.toml`.
        See <https://hunk.dev/docs/reference/config/> for supported values.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    # hunk offers to persist changed view preferences into its config, which is read-only here
    programs.hunk.settings.prompt_save_view_preferences = lib.mkDefault false;

    xdg.configFile."hunk/config.toml".source = tomlFormat.generate "hunk-config.toml" cfg.settings;
  };
}
