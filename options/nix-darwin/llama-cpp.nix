{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.llama-cpp;
  inherit (lib) types;
in
{
  options = {
    services.llama-cpp = {
      enable = lib.mkEnableOption "llama.cpp HTTP server";

      package = lib.mkPackageOption pkgs "llama-cpp" { };

      settings = lib.mkOption {
        type = types.submodule {
          freeformType = types.attrs;
          options = {
            host = lib.mkOption {
              type = types.str;
              default = "127.0.0.1";
              example = "0.0.0.0";
              description = ''
                IP address on which the server should listen on.
              '';
            };

            port = lib.mkOption {
              type = types.port;
              default = 8080;
              example = 1337;
              description = ''
                Port on which the server should listen on.
              '';
            };
          };
        };
        default = { };
        example = {
          host = "0.0.0.0";
          port = 1337;
          model = "/mnt/llms/Foo3.6-27B-UD-Q4_K_XL.gguf";
          ctx-size = 252144;
          temp = 0.6;
          top-k = 20;
          top-p = 0.95;
          batch-size = 512;
          ubatch-size = 256;
          spec-type = "draft-mtp";
          spec-draft-n-max = 2;
          flash-attn = "on";
        };
        description = ''
          Command-line arguments for `llama-server`.

          See <https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md>
          for the full list of options.
        '';
      };

      home = lib.mkOption {
        type = types.str;
        default = "/private/var/lib/llama-cpp";
        description = ''
          The home directory that the llama-cpp service is started in.
        '';
      };

      cache = lib.mkOption {
        type = types.str;
        default = "/private/var/cache/llama-cpp";
        description = ''
          The cache directory used by llama-cpp (LLAMA_CACHE).
        '';
      };

      log = lib.mkOption {
        type = types.str;
        default = "/private/var/log/llama-cpp.log";
        description = ''
          The file that the llama-cpp service will write logs to.
        '';
      };

      environmentVariables = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          GGML_METAL_PATH_RESOURCES = "/some/path";
        };
        description = ''
          Set arbitrary environment variables for the llama-cpp service.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.daemons.llama-cpp = {
      environment = cfg.environmentVariables // {
        HOME = cfg.home;
        LLAMA_CACHE = cfg.cache;
      };
      serviceConfig = {
        ProgramArguments = [
          (lib.getExe' cfg.package "llama-server")
        ]
        ++ lib.cli.toCommandLine (optionName: {
          option = if builtins.stringLength optionName > 1 then "--${optionName}" else "-${optionName}";
          sep = null;
          explicitBool = false;
          formatArg = lib.generators.mkValueStringDefault { };
        }) cfg.settings;
        KeepAlive = true;
        RunAtLoad = true;
        ExitTimeOut = 90;
        ThrottleInterval = 10;
        UserName = "_llamacpp";
        GroupName = "_llamacpp";
        WorkingDirectory = cfg.home;
        StandardOutPath = cfg.log;
        StandardErrorPath = cfg.log;
      };
    };

    users = {
      users._llamacpp = {
        uid = config.ids.uids._llamacpp;
        gid = config.users.groups._llamacpp.gid;
        shell = lib.mkDefault null;
        home = cfg.home;
        description = "LLaMA C++ service user";
        isHidden = true;
      };
      groups._llamacpp = {
        gid = config.ids.gids._llamacpp;
        description = "LLaMA C++ service group";
      };
    };

    system.activationScripts.preActivation.text = ''
      mkdir -p "${cfg.home}" "${cfg.cache}"
      touch "${cfg.log}"
      chown ${toString config.users.users._llamacpp.uid}:${toString config.users.users._llamacpp.gid} "${cfg.home}" "${cfg.cache}" "${cfg.log}"
    '';
  };
}
