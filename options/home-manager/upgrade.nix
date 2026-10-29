{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.custom.autoUpgrade;
  name = "infra-upgrade";
  description = "Infra upgrade";

  upgrade = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [
      config.programs.home-manager.package
      config.nix.package
    ];
    text = ''
      home-manager switch \
        --flake ${lib.escapeShellArg cfg.flake} \
        --refresh \
        ${lib.escapeShellArgs cfg.flags}
    '';
  };
in
{
  options.custom.autoUpgrade = {
    enable = lib.mkEnableOption "periodic home-manager auto upgrade";

    flake = lib.mkOption {
      type = lib.types.str;
      example = "github:user/repo";
      description = ''
        Flake URI of the configuration to build.
      '';
    };

    hour = lib.mkOption {
      type = lib.types.ints.between 0 23;
      default = 4;
      description = ''
        Hour of the daily upgrade.
      '';
    };

    minute = lib.mkOption {
      type = lib.types.ints.between 0 59;
      default = 40;
      description = ''
        Minute of the daily upgrade.
      '';
    };

    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--option"
        "extra-builtins-file"
        "/path/to/file"
      ];
      description = ''
        Additional flags passed to {command}`home-manager switch`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      services.${name} = {
        Unit = {
          Description = description;
          # a switch restarting this unit would kill the upgrade that runs it
          X-SwitchMethod = "keep-old";
        };
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe upgrade;
        };
      };

      timers.${name} = {
        Unit.Description = description;
        Timer = {
          OnCalendar = "*-*-* ${toString cfg.hour}:${toString cfg.minute}:00";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };

    # launchd catches up on a missed run after sleep, like a persistent timer
    launchd.agents.${name} = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      # the background session outlives a logout, unlike the default gui domain
      domain = "user";
      config = {
        ProgramArguments = [ (lib.getExe upgrade) ];
        StartCalendarInterval = [
          {
            Hour = cfg.hour;
            Minute = cfg.minute;
          }
        ];
        ProcessType = "Background";
      };
    };
  };
}
