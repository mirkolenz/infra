# Runs the `services.kopia` jobs as launchd daemons, the backups on a calendar interval.
# launchd catches up on an interval missed during sleep once the Mac wakes.
{
  config,
  lib,
  modulesPath,
  ...
}:
let
  cfg = config.services.kopia.repositories;
  launchdTypes = import "${modulesPath}/launchd/types.nix" { inherit config lib; };

  logFile = repo: job: "${repo.dirs.log}/${job}.log";

  jobConfig = repo: {
    backup = {
      StartCalendarInterval = repo.interval;
      ProcessType = "Background";
      LowPriorityIO = true;
    };
    server = {
      KeepAlive = true;
      RunAtLoad = true;
      ThrottleInterval = 10;
    };
  };
in
{
  imports = [ ../shared/_kopia.nix ];

  options.services.kopia.repositories = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.interval = lib.mkOption {
          type = launchdTypes.StartCalendarInterval;
          default = [
            {
              Hour = 12;
              Minute = 0;
            }
          ];
          description = "The calendar interval at which the backup runs.";
        };
      }
    );
  };

  config = {
    services.kopia.sleepInhibitor = [
      "/usr/bin/caffeinate"
      "-i"
    ];

    launchd.daemons = lib.concatMapAttrs (
      name: repo:
      lib.mapAttrs' (
        job: script:
        lib.nameValuePair "kopia-${name}-${job}" {
          # The Apple-signed /bin/bash runs the script, so Full Disk Access granted to it survives rebuilds.
          command = "/bin/bash ${script}";
          serviceConfig = {
            UserName = repo.user;
            StandardOutPath = logFile repo job;
            StandardErrorPath = logFile repo job;
          }
          // (jobConfig repo).${job};
        }
      ) repo.jobs
    ) cfg;

    system.newsyslog = lib.mkIf (cfg != { }) {
      enable = true;
      files.kopia = lib.concatLists (
        lib.mapAttrsToList (
          _: repo:
          lib.mapAttrsToList (job: _: {
            logfilename = logFile repo job;
            owner = repo.user;
            size = "1024";
            # launchd reopens the log on every start, so no process needs a signal
            flags = [
              "Z"
              "N"
            ];
          }) repo.jobs
        ) cfg
      );
    };

    # after the users exist and before launchd loads the server
    system.activationScripts.launchd.text = lib.mkBefore (
      lib.concatLines (
        lib.mapAttrsToList (
          _: repo: "install -d -m 0700 -o ${repo.user} ${lib.escapeShellArgs (lib.attrValues repo.dirs)}"
        ) cfg
      )
    );
  };
}
