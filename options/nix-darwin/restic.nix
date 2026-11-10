# The NixOS `services.restic.backups` interface on darwin, reusing its options.
# The launchd `interval` replaces the systemd `timerConfig`, as `nix.gc.interval` does for `nix.gc.dates`.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  cfg = config.services.restic.backups;

  nixosOption =
    (import "${pkgs.path}/nixos/modules/services/backup/restic.nix" {
      inherit config lib pkgs;
      # only types timerConfig, which darwin ignores
      utils.systemdUtils.unitOptions.unitOption = lib.types.anything;
    }).options.services.restic.backups;

  launchdTypes = import "${modulesPath}/launchd/types.nix" { inherit config lib; };

  cacheDir = name: "/private/var/cache/restic-backups-${name}";
  logFile = name: "/private/var/log/restic-backups-${name}.log";

  hasPaths = backup: backup.paths != null && backup.paths != [ ];
  isFileBackup = backup: hasPaths backup || backup.dynamicFilesFrom != null;
  isCommandBackup = backup: backup.command != [ ];

  # Exports the variables of the NixOS service, the environment file takes precedence as in systemd.
  mkEnvironment =
    name: backup:
    let
      rcloneRemoteName = lib.elemAt (lib.splitString ":" backup.repository) 1;
      toRcloneVal = v: if lib.isBool v then lib.boolToString v else v;
      mapRclone =
        toName: attrs:
        lib.mapAttrs' (n: v: lib.nameValuePair (toName n) (toRcloneVal v)) (lib.defaultTo { } attrs);
      variables = lib.filterAttrs (_: v: v != null) (
        {
          RESTIC_PASSWORD_FILE = backup.passwordFile;
          RESTIC_REPOSITORY = backup.repository;
          RESTIC_REPOSITORY_FILE = backup.repositoryFile;
          RESTIC_CACHE_DIR = if backup.noCache then null else cacheDir name;
          RESTIC_PROGRESS_FPS = lib.mapNullable toString backup.progressFps;
          RCLONE_CONFIG = backup.rcloneConfigFile;
        }
        // mapRclone (
          n: "RCLONE_" + lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] n)
        ) backup.rcloneOptions
        // mapRclone (n: "RCLONE_CONFIG_" + lib.toUpper "${rcloneRemoteName}_${n}") backup.rcloneConfig
      );
    in
    ''
      set -a
      ${lib.toShellVars variables}
      ${lib.optionalString (backup.environmentFile != null) "source ${backup.environmentFile}"}
      set +a
    '';

  mkResticCmd =
    backup:
    toString (
      [ (lib.getExe backup.package) ]
      ++ map (arg: "-o ${arg}") backup.extraOptions
      ++ lib.optional backup.noCache "--no-cache"
    );

  mkScript =
    name: backup:
    let
      resticCmd = mkResticCmd backup;
      fileBackup = isFileBackup backup;
      commandBackup = isCommandBackup backup;
      excludeFile = pkgs.writeText "exclude-patterns" (lib.concatLines backup.exclude);
      backupArgs =
        backup.extraBackupArgs
        ++ lib.optionals fileBackup (
          [ ''--files-from="$files"'' ]
          ++ lib.optional (backup.exclude != [ ]) "--exclude-file=${excludeFile}"
        )
        ++ lib.optionals commandBackup ([ "--stdin-from-command=true --" ] ++ backup.command);
      cleanup =
        lib.optional fileBackup ''rm -f "$files"''
        ++ lib.optional (
          backup.backupCleanupCommand != null
        ) "${pkgs.writeScript "backupCleanupCommand" backup.backupCleanupCommand}";
    in
    pkgs.writeShellScript "restic-backups-${name}" (
      lib.concatLines (
        [
          "set -euo pipefail"
          (mkEnvironment name backup)
        ]
        ++ lib.optional backup.inhibitsSleep "/usr/bin/caffeinate -i -w $$ &"
        ++ lib.optional fileBackup "files=$(mktemp)"
        ++ lib.optionals (cleanup != [ ]) [
          "cleanup() { ${lib.concatStringsSep "; " cleanup}; }"
          "trap cleanup EXIT"
        ]
        ++ lib.optional (
          backup.backupPrepareCommand != null
        ) "${pkgs.writeScript "backupPrepareCommand" backup.backupPrepareCommand}"
        ++ lib.optional backup.initialize ''
          ${resticCmd} cat config --no-lock > /dev/null || {
            status=$?
            if [ "$status" -eq 10 ]; then
              ${resticCmd} init
            else
              exit "$status"
            fi
          }
        ''
        ++ lib.optional (hasPaths backup) ''cat ${pkgs.writeText "staticPaths" (lib.concatLines backup.paths)} >> "$files"''
        ++ lib.optional (
          backup.dynamicFilesFrom != null
        ) ''${pkgs.writeScript "dynamicFilesFromScript" backup.dynamicFilesFrom} >> "$files"''
        ++ lib.optional (fileBackup || commandBackup) "${resticCmd} backup ${toString backupArgs}"
        ++ lib.optionals (backup.pruneOpts != [ ]) [
          "${resticCmd} unlock"
          "${resticCmd} forget --prune ${toString backup.pruneOpts}"
        ]
        ++ lib.optional backup.runCheck "${resticCmd} check ${toString backup.checkOpts}"
      )
    );
in
{
  options.services.restic.backups = lib.mkOption {
    inherit (nixosOption) default description example;
    type = lib.types.attrsOf (
      lib.types.submodule (
        nixosOption.type.nestedTypes.elemType.getSubModules
        ++ [
          {
            options.interval = lib.mkOption {
              type = lib.types.nullOr launchdTypes.StartCalendarInterval;
              default = [
                {
                  Hour = 0;
                  Minute = 0;
                }
              ];
              description = ''
                The calendar interval at which the backup runs, `timerConfig` is ignored on darwin.
                If null, the backup only runs when started with `launchctl kickstart`.
              '';
            };
          }
        ]
      )
    );
  };

  config = {
    # vendored from the NixOS module
    assertions = lib.concatLists (
      lib.mapAttrsToList (
        name: backup:
        map (a: a // { message = "services.restic.backups.${name}: ${a.message}"; }) [
          {
            assertion =
              ((backup.repository == null) != (backup.repositoryFile == null))
              || (backup.environmentFile != null);
            message = "exactly one of repository, repositoryFile or environmentFile should be set";
          }
          {
            assertion = !(isFileBackup backup && isCommandBackup backup);
            message = "cannot do both a command backup and a file backup at the same time.";
          }
          {
            assertion = (backup.passwordFile != null) || (backup.environmentFile != null);
            message = "passwordFile or environmentFile must be set";
          }
        ]
      ) cfg
    );

    launchd.daemons = lib.mapAttrs' (
      name: backup:
      lib.nameValuePair "restic-backups-${name}" {
        # The Apple-signed /bin/bash replaces the launchd shell and runs the script,
        # so Full Disk Access granted to it survives rebuilds.
        command = "/bin/bash ${mkScript name backup}";
        serviceConfig = {
          StartCalendarInterval = backup.interval;
          UserName = backup.user;
          StandardOutPath = logFile name;
          StandardErrorPath = logFile name;
        };
      }
    ) cfg;

    environment.systemPackages = lib.mapAttrsToList (
      name: backup:
      pkgs.writeShellScriptBin "restic-${name}" ''
        ${mkEnvironment name backup}
        exec ${mkResticCmd backup} "$@"
      ''
    ) (lib.filterAttrs (_: backup: backup.createWrapper) cfg);

    system.newsyslog = lib.mkIf (cfg != { }) {
      enable = true;
      files.restic = lib.mapAttrsToList (name: backup: {
        logfilename = logFile name;
        owner = backup.user;
        size = "1024";
        # launchd reopens the log on every run, so no process needs a signal
        flags = [
          "Z"
          "N"
        ];
      }) cfg;
    };

    system.activationScripts.postActivation.text = lib.concatLines (
      lib.mapAttrsToList (name: backup: ''
        ${lib.optionalString (!backup.noCache) ''install -d -m 0700 -o ${backup.user} "${cacheDir name}"''}
        touch "${logFile name}"
        chown ${backup.user} "${logFile name}"
      '') cfg
    );
  };
}
