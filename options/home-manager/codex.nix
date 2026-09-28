# Extends home-manager's `programs.codex` with installations for further accounts,
# a writable config, and a pinned app-server daemon.
# Unlike its `profiles`, which share one CODEX_HOME, each installation has a login of its own.
# https://github.com/nix-community/home-manager/blob/master/modules/programs/codex
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.codex;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  imports = [
    # Codex keeps auth.json, history and sessions inside CODEX_HOME,
    # so installations share everything else with the regular one.
    (import ./_installations.nix {
      program = "codex";
      inherit (cfg) package;
      envVar = "CODEX_HOME";
      format = "toml";
      # Codex writes trust decisions back to config.toml, which fails on a read-only
      # store symlink (https://github.com/openai/codex/issues/6646). Replace it with a
      # writable copy of the generated config per installation,
      # trust resets on each activation.
      settingsFile = ".codex/config.toml";
      mutable = true;
      sharedEntries = [
        "AGENTS.md"
        "skills"
      ];
      example.work.forced_chatgpt_workspace_id = "00000000-0000-0000-0000-000000000000";
    })
  ];

  # The app-server daemon runs whatever package `current` selects and only installs
  # a copy when it is missing, which fails for a tree linking into the store. A store
  # path also keeps its self-updater disabled. Every CODEX_HOME needs its own link.
  # Packages opt in by exposing their tree as `passthru.appServerDaemon`.
  config = lib.mkIf (cfg.enable && cfg.package ? appServerDaemon) {
    home.file = lib.genAttrs' cfg.configDirs (
      dir:
      lib.nameValuePair "${dir}/packages/app-server-daemon/current" {
        source = cfg.package.appServerDaemon;
        # A running daemon keeps its old binary until restarted.
        onChange = /* bash */ ''
          if [[ -e "${dir}/app-server-daemon/daemon.pid" ]]; then
            CODEX_HOME=${dir} run ${lib.getExe cfg.package} app-server daemon restart \
              || warnEcho "Failed to restart the codex app-server daemon in ${dir}"
          fi
        '';
      }
    );

    # The restart looks up `ps` in PATH to record the new daemon's start time.
    home.extraActivationPath = with pkgs; [
      unixtools.ps
    ];
  };
}
