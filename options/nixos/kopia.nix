# Runs the `services.kopia` jobs as systemd services, the backups on a timer.
{
  config,
  lib,
  utils,
  ...
}:
let
  cfg = config.services.kopia.repositories;

  jobConfig = {
    backup.serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
    server = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 10;
      };
    };
  };
in
{
  imports = [ ../shared/_kopia.nix ];

  options.services.kopia.repositories = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.timerConfig = lib.mkOption {
          type = lib.types.attrsOf utils.systemdUtils.unitOptions.unitOption;
          default = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
          description = "When the backup runs, see {manpage}`systemd.timer(5)`.";
        };
      }
    );
  };

  config = {
    services.kopia.sleepInhibitor = [
      "${config.systemd.package}/bin/systemd-inhibit"
      "--mode=block"
      "--who=kopia"
      "--what=sleep"
      "--why=Kopia backup"
    ];

    systemd.services = lib.concatMapAttrs (
      name: repo:
      lib.mapAttrs' (
        job: script:
        lib.nameValuePair "kopia-${name}-${job}" (
          lib.recursiveUpdate {
            description = "Kopia ${job} of ${name}";
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            unitConfig.RequiresMountsFor =
              repo.paths ++ lib.optional (repo.backend == "filesystem") repo.settings.path;
            serviceConfig = {
              ExecStart = script;
              User = repo.user;
              StateDirectory = repo.directory;
              CacheDirectory = repo.directory;
              LogsDirectory = repo.directory;
              StateDirectoryMode = "0700";
              CacheDirectoryMode = "0700";
              LogsDirectoryMode = "0700";
              PrivateTmp = true;
              ProtectSystem = "full";
            };
          } jobConfig.${job}
        )
      ) repo.jobs
    ) cfg;

    systemd.timers = lib.concatMapAttrs (
      name: repo:
      lib.optionalAttrs (repo.jobs ? backup) {
        "kopia-${name}-backup" = {
          wantedBy = [ "timers.target" ];
          inherit (repo) timerConfig;
        };
      }
    ) cfg;
  };
}
