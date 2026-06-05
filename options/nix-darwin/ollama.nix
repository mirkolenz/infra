{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ollama;
  inherit (lib) types;
in
{
  options = {
    services.ollama = {
      enable = lib.mkEnableOption "Ollama Daemon";

      package = lib.mkPackageOption pkgs "ollama" { };

      host = lib.mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = ''
          The host address which the ollama server HTTP interface listens to.
        '';
      };

      port = lib.mkOption {
        type = types.port;
        default = 11434;
        description = ''
          Which port the ollama server listens to.
        '';
      };

      home = lib.mkOption {
        type = types.str;
        default = "/var/lib/ollama";
        description = ''
          The home directory that the ollama service is started in.
        '';
      };

      models = lib.mkOption {
        type = types.str;
        default = "${cfg.home}/models";
        description = ''
          The directory that the ollama service will read models from and download new models to.
        '';
      };

      log = lib.mkOption {
        type = types.str;
        default = "/var/log/ollama.log";
        description = ''
          The directory that the ollama service will write logs to.
        '';
      };

      environmentVariables = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          OLLAMA_LLM_LIBRARY = "cpu";
        };
        description = ''
          Set arbitrary environment variables for the ollama service.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.daemons.ollama = {
      environment = cfg.environmentVariables // {
        HOME = cfg.home;
        OLLAMA_MODELS = cfg.models;
        OLLAMA_HOST = "${cfg.host}:${toString cfg.port}";
      };
      serviceConfig = {
        ProgramArguments = [
          (lib.getExe cfg.package)
          "serve"
        ];
        KeepAlive = true;
        RunAtLoad = true;
        ExitTimeOut = 5;
        UserName = "_ollama";
        GroupName = "_ollama";
        WorkingDirectory = cfg.home;
        StandardOutPath = cfg.log;
        StandardErrorPath = cfg.log;
      };
    };

    users = {
      users._ollama = {
        uid = config.ids.uids._ollama;
        gid = config.users.groups._ollama.gid;
        shell = lib.mkDefault null;
        home = cfg.home;
        description = "Ollama service user";
        isHidden = true;
      };
      groups._ollama = {
        gid = config.ids.gids._ollama;
        description = "Ollama service group";
      };
    };

    system.activationScripts.preActivation.text = ''
      mkdir -p "${cfg.home}" "${cfg.models}"
      touch "${cfg.log}"
      chown ${toString config.users.users._ollama.uid}:${toString config.users.users._ollama.gid} "${cfg.home}" "${cfg.models}" "${cfg.log}"
    '';
  };
}
