{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.llama-cpp;
  inherit (lib) types;

  modelsPresetFile =
    if cfg.modelsPreset != null then
      pkgs.writeText "llama-models.ini" (lib.generators.toINI { } cfg.modelsPreset)
    else
      null;
in
{
  options = {
    services.llama-cpp = {
      enable = lib.mkEnableOption "LLaMA C++ server";

      package = lib.mkPackageOption pkgs "llama-cpp" { };

      model = lib.mkOption {
        type = types.nullOr types.path;
        example = "/models/mistral-instruct-7b/ggml-model-q4_0.gguf";
        description = "Model path.";
        default = null;
      };

      modelsDir = lib.mkOption {
        type = types.nullOr types.path;
        example = "/models/";
        description = "Models directory.";
        default = null;
      };

      modelsPreset = lib.mkOption {
        type = types.nullOr (types.attrsOf types.attrs);
        default = null;
        description = ''
          Models preset configuration as a Nix attribute set.
          This is converted to an INI file and passed to llama-server via --model-preset.
          See llama-server documentation for available options.
        '';
        example = lib.literalExpression ''
          {
            "Qwen3-Coder-Next" = {
              hf-repo = "unsloth/Qwen3-Coder-Next-GGUF";
              hf-file = "Qwen3-Coder-Next-UD-Q4_K_XL.gguf";
              alias = "unsloth/Qwen3-Coder-Next";
              fit = "on";
              seed = "3407";
              temp = "1.0";
              top-p = "0.95";
              min-p = "0.01";
              top-k = "40";
              jinja = "on";
            };
          }
        '';
      };

      extraFlags = lib.mkOption {
        type = types.listOf types.str;
        description = "Extra flags passed to llama-cpp-server.";
        example = [
          "-c"
          "4096"
          "-ngl"
          "32"
        ];
        default = [ ];
      };

      host = lib.mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = "IP address the LLaMA C++ server listens on.";
      };

      port = lib.mkOption {
        type = types.port;
        default = 8080;
        description = "Listen port for LLaMA C++ server.";
      };

      home = lib.mkOption {
        type = types.str;
        default = "/var/lib/llama-cpp";
        description = ''
          The home directory that the llama-cpp service is started in.
        '';
      };

      cache = lib.mkOption {
        type = types.str;
        default = "/var/cache/llama-cpp";
        description = ''
          The cache directory used by llama-cpp (LLAMA_CACHE).
        '';
      };

      log = lib.mkOption {
        type = types.str;
        default = "/var/log/llama-cpp.log";
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
          "--host"
          cfg.host
          "--port"
          (toString cfg.port)
        ]
        ++ lib.optionals (cfg.model != null) [
          "-m"
          cfg.model
        ]
        ++ lib.optionals (cfg.modelsDir != null) [
          "--models-dir"
          cfg.modelsDir
        ]
        ++ lib.optionals (cfg.modelsPreset != null) [
          "--models-preset"
          (toString modelsPresetFile)
        ]
        ++ cfg.extraFlags;
        KeepAlive = true;
        RunAtLoad = true;
        ExitTimeOut = 90;
        ThrottleInterval = 300;
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
