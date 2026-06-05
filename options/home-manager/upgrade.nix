{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.custom.autoUpgrade;
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

    dates = lib.mkOption {
      type = lib.types.str;
      default = "04:40";
      example = "daily";
      description = ''
        How often to upgrade. The format is described in
        {manpage}`systemd.time(7)`.
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

    persistent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether the timer should be persistent.
        If true, the time when the service unit was last triggered is stored on disk.
        When the timer is activated, the service unit is triggered immediately
        if it would have been triggered at least once during the time when the timer was inactive.
      '';
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "0";
      example = "45min";
      description = ''
        Adds a randomized delay before each upgrade.
        The delay is useful to distribute load on the flake source.
        See {manpage}`systemd.timer(5)` for details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "custom.autoUpgrade" pkgs lib.platforms.linux)
    ];

    systemd.user = {
      services.custom-home-manager-auto-upgrade = {
        Unit = {
          Description = "Custom Home Manager auto upgrade";
        };
        Service = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "custom-home-manager-auto-upgrade" ''
            home-manager switch \
              --flake ${lib.escapeShellArg cfg.flake} \
              --refresh \
              ${lib.escapeShellArgs cfg.flags}
          '';
          ExecSearchPath = lib.makeBinPath [
            config.programs.home-manager.package
            config.nix.package
          ];
        };
      };

      timers.custom-home-manager-auto-upgrade = {
        Unit = {
          Description = "Custom Home Manager auto upgrade timer";
        };
        Timer = {
          OnCalendar = cfg.dates;
          Persistent = cfg.persistent;
          RandomizedDelaySec = cfg.randomizedDelaySec;
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      };
    };
  };
}
