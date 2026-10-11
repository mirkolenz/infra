# nono, a capability-based sandbox for running AI agents and other commands.
# https://github.com/nolabs-ai/nono
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.programs.nono;

  jsonFormat = pkgs.formats.json { };
  tomlFormat = pkgs.formats.toml { };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.nono = {
    enable = lib.mkEnableOption "nono";

    package = lib.mkPackageOption pkgs "nono-bin" { };

    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      description = "The package with {option}`programs.nono.environment` baked in.";
    };

    settings = mkOption {
      inherit (tomlFormat) type;
      default = { };
      example.ui.theme = "latte";
      description = "Configuration written to {file}`$XDG_CONFIG_HOME/nono/config.toml`.";
    };

    profiles = mkOption {
      type = types.attrsOf jsonFormat.type;
      default = { };
      example.dev = {
        extends = "default";
        network.allow_domain = [ "github.com" ];
      };
      description = ''
        Profiles written to {file}`$XDG_CONFIG_HOME/nono/profiles/<name>.json`,
        linked one by one since nono writes drafts and packs next to them.
        Names consist of letters, digits and inner dashes, as nono requires.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example.NONO_PROFILE = "dev";
      description = "Variables set for every invocation of nono, unless set already.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (name: lib.match "[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?" name != null) (
          lib.attrNames cfg.profiles
        );
        message = "programs.nono.profiles: names must consist of letters, digits and inner dashes.";
      }
    ];

    programs.nono = {
      environment = lib.mapAttrs (_: lib.mkDefault) {
        NONO_NO_UPDATE_CHECK = "1";
        NONO_NO_PACK_UPDATE_HINTS = "1";
        NONO_NO_MIGRATE = "1";
        NONO_NO_SAVE_PROMPT = "1";
      };

      finalPackage = pkgs.symlinkJoin {
        inherit (cfg.package) name meta;
        paths = [ cfg.package ];
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
        postBuild = "wrapProgram $out/bin/nono ${
          lib.concatMapAttrsStringSep " " (
            name: value: "--set-default ${lib.escapeShellArg name} ${lib.escapeShellArg value}"
          ) cfg.environment
        }";
      };
    };

    home.packages = [ cfg.finalPackage ];

    xdg.configFile = {
      "nono/config.toml" = lib.mkIf (cfg.settings != { }) {
        source = tomlFormat.generate "nono-config.toml" cfg.settings;
      };
    }
    // lib.mapAttrs' (
      name: profile:
      lib.nameValuePair "nono/profiles/${name}.json" {
        source = jsonFormat.generate "nono-profile-${name}.json" (
          {
            "$schema" =
              "https://raw.githubusercontent.com/nolabs-ai/nono/v${cfg.package.version}/crates/nono-cli/data/nono-profile.schema.json";
          }
          // profile
        );
      }
    ) cfg.profiles;
  };
}
