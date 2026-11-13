# `services.kopia` for NixOS and nix-darwin, whose modules run the generated scripts.
# The repository connection lives in the state directory, without persisting the password.
# It is renewed whenever the connection arguments change, and the policies are imported on every start.
# The server runs the web UI, along with the scheduler of the sources added there and the maintenance.
# The leading underscore hides this declaration from import-tree.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.kopia;
  inherit (config.networking) hostName;
  inherit (lib) types;
  jsonFormat = pkgs.formats.json { };
  kopia = lib.getExe cfg.package;
  toArgs = lib.cli.toCommandLineGNU { };

  settingsType = types.attrsOf (
    types.nullOr (
      types.oneOf [
        types.bool
        types.int
        types.str
        (types.listOf types.str)
      ]
    )
  );

  # Exports the variables of kopia, failing when a secret is unreadable.
  mkEnvironment = repo: ''
    set -euo pipefail
    set -a
    ${lib.toShellVars {
      KOPIA_CONFIG_PATH = "${repo.dirs.state}/repository.config";
      KOPIA_CACHE_DIRECTORY = repo.dirs.cache;
      KOPIA_LOG_DIR = repo.dirs.log;
      KOPIA_CHECK_FOR_UPDATES = "false";
      KOPIA_PERSIST_CREDENTIALS_ON_CONNECT = "false";
    }}
    KOPIA_PASSWORD=$(< ${lib.escapeShellArg repo.passwordFile})
    ${lib.optionalString (
      repo.environmentFile != null
    ) "source ${lib.escapeShellArg repo.environmentFile}"}
    set +a
  '';

  # Serialized by a lock, since the jobs of a repository share its connection,
  # and released before the job runs, since the server holds on to its descriptors.
  mkConnectArgs = repo: lib.escapeShellArgs ([ repo.backend ] ++ toArgs repo.settings);

  mkConnect = name: repo: ''
    stamp=${lib.escapeShellArg "${repo.dirs.state}/connection"}
    hash=${lib.hashString "sha256" (mkConnectArgs repo)}

    {
      ${lib.getExe' pkgs.flock "flock"} 9

      if [[ ! -f $KOPIA_CONFIG_PATH || ! -f $stamp || $(< "$stamp") != "$hash" ]]; then
        if [[ -f $KOPIA_CONFIG_PATH ]]; then
          ${kopia} repository disconnect
        fi

        ${kopia} repository connect ${mkConnectArgs repo}${lib.optionalString repo.initialize " || ${kopia} repository create ${mkConnectArgs repo}"}
        echo "$hash" > "$stamp"
      fi

      ${lib.optionalString (repo.policies != { } || repo.deleteOtherPolicies) ''
        ${kopia} policy import --from-file=${jsonFormat.generate "kopia-${name}-policies.json" repo.policies}${lib.optionalString repo.deleteOtherPolicies " --delete-other-policies"}
      ''}
    } 9> ${lib.escapeShellArg "${repo.dirs.state}/lock"}
  '';

  mkJob =
    name: repo: job: text:
    pkgs.writeShellScript "kopia-${name}-${job}" ''
      ${mkEnvironment repo}
      ${mkConnect name repo}
      ${text}
    '';

  repositoryModule =
    { name, config, ... }:
    {
      options = {
        user = lib.mkOption {
          type = types.str;
          default = "root";
          description = "The user that runs the backups and the server.";
        };

        backend = lib.mkOption {
          type = types.str;
          example = "s3";
          description = "The storage backend, a subcommand of `kopia repository connect`.";
        };

        settings = lib.mkOption {
          type = settingsType;
          default = { };
          example = {
            bucket = "backups";
            endpoint = "s3.eu-central-1.wasabisys.com";
            prefix = "macbook/";
          };
          description = ''
            Flags of `kopia repository connect <backend>`, covering the backend and the connection.
            Secrets like `AWS_SECRET_ACCESS_KEY` belong into {option}`environmentFile`.
            Changing them reconnects the repository.
          '';
        };

        passwordFile = lib.mkOption {
          type = types.str;
          description = "File containing the repository password.";
        };

        environmentFile = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Bash script sourced before kopia runs, exporting variables such as the credentials of the backend.";
        };

        initialize = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Whether to create the repository if connecting to it fails.";
        };

        paths = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Paths to snapshot on schedule, none disables the scheduled backup.";
        };

        policies = lib.mkOption {
          inherit (jsonFormat) type;
          default = { };
          example = {
            "(global)" = {
              retention = {
                keepDaily = 7;
                keepWeekly = 4;
                keepMonthly = 12;
                keepAnnual = 3;
              };
              files.ignore = [
                ".cache"
                "node_modules"
              ];
            };
          };
          description = ''
            Policies imported before every backup and server start, keyed by target like `(global)` or `user@host:/path`.
            A `scheduling` policy makes the server snapshot the path as well.
            See `kopia policy export` for the format.
          '';
        };

        deleteOtherPolicies = lib.mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to delete the policies missing from {option}`policies`.
            This includes the sources added in the web UI, which then lose their schedule.
          '';
        };

        server = {
          enable = lib.mkEnableOption ''
            the Kopia server with its web UI.
            Sources added there are snapshotted by the server according to their `scheduling` policy
          '';

          passwordFile = lib.mkOption {
            type = types.str;
            description = "File containing the password of the web UI.";
          };

          settings = lib.mkOption {
            type = types.submodule {
              freeformType = settingsType;
              options.address = lib.mkOption {
                type = types.str;
                default = "http://127.0.0.1:51515";
                description = "The address the server listens on.";
              };
            };
            default = { };
            example.server-username = "admin";
            description = ''
              Flags of `kopia server start`.
              Without `tls-cert-file`, the server runs without TLS and belongs behind a reverse proxy.
            '';
          };
        };

        directory = lib.mkOption {
          type = types.str;
          internal = true;
          readOnly = true;
          default = "kopia/${name}";
          description = "The name of the state, cache and log directories.";
        };

        dirs = lib.mkOption {
          type = types.attrsOf types.str;
          internal = true;
          readOnly = true;
          default = lib.mapAttrs (_: root: "${root}/${config.directory}") {
            state = "/var/lib";
            cache = "/var/cache";
            log = "/var/log";
          };
        };

        jobs = lib.mkOption {
          type = types.attrsOf types.package;
          internal = true;
          readOnly = true;
          description = "The scripts of the enabled jobs, run by the platform modules.";
        };

        wrapper = lib.mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
        };
      };

      config = {
        # stable across network changes, unlike the hostname of macOS
        settings.override-hostname = lib.mkDefault hostName;

        jobs =
          lib.optionalAttrs (config.paths != [ ]) {
            backup = mkJob name config "backup" (
              lib.escapeShellArgs (
                cfg.sleepInhibitor
                ++ [
                  kopia
                  "snapshot"
                  "create"
                ]
                ++ config.paths
              )
            );
          }
          // lib.optionalAttrs config.server.enable {
            server = mkJob name config "server" ''
              KOPIA_SERVER_PASSWORD=$(< ${lib.escapeShellArg config.server.passwordFile}) exec ${kopia} server start ${
                lib.escapeShellArgs (
                  toArgs config.server.settings
                  ++ lib.optional (config.server.settings.tls-cert-file or null == null) "--insecure"
                )
              }
            '';
          };

        wrapper = pkgs.writeShellScriptBin "kopia-${name}" ''
          ${mkEnvironment config}
          exec ${kopia} "$@"
        '';
      };
    };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.services.kopia = {
    package = lib.mkPackageOption pkgs "kopia" { };

    sleepInhibitor = lib.mkOption {
      type = types.listOf types.str;
      internal = true;
      description = "Command prefix that keeps the system awake during a backup, set by the platform module.";
    };

    repositories = lib.mkOption {
      type = types.attrsOf (types.submodule repositoryModule);
      default = { };
      description = "Kopia repositories, each with scheduled backups of its paths and an optional server.";
    };
  };

  config = {
    assertions = lib.mapAttrsToList (name: repo: {
      assertion = repo.backend == "filesystem" -> repo.settings ? path;
      message = "services.kopia.repositories.${name}: the filesystem backend requires settings.path.";
    }) cfg.repositories;

    environment.systemPackages = lib.mapAttrsToList (_: repo: repo.wrapper) cfg.repositories;
  };
}
