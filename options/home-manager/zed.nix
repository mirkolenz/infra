# Zed, whose configuration files are installed as writable copies.
# Zed rewrites them at runtime, which fails on read-only store symlinks,
# so they reset to the generated content on each rebuild.
# The shared languages of options/shared/_editors map onto its settings. Each server runs
# from its Nix package, and Zed starts no others, so it never downloads one on its own.
{
  config,
  lib,
  lib',
  pkgs,
  ...
}:
let
  inherit (lib) mkOption;
  inherit (config.custom) editors languages tools;

  cfg = config.custom.zed;
  jsonFormat = pkgs.formats.json { };
  servers = config.custom.active.servers;

  jsonOption =
    file: default:
    mkOption {
      inherit (jsonFormat) type;
      inherit default;
      description = "Content of Zed's {file}`${file}`.";
    };

  mkServer =
    server:
    {
      binary = {
        path = server.command;
        arguments = server.args;
      };
    }
    // lib.optionalAttrs (server.editors.zed.settings != { }) {
      inherit (server.editors.zed) settings;
    }
    // lib.optionalAttrs (server.initializationOptions != { }) {
      initialization_options = server.initializationOptions;
    };

  zedName = name: servers.${name}.editors.zed.name;
  universal = map zedName config.custom.universal.servers;

  # Zed runs the tools that read stdin, and code actions of the servers in place of the others.
  mkTool =
    name:
    let
      tool = tools.${name};
    in
    if tool.editors.zed.codeAction != null then
      [ { code_action = tool.editors.zed.codeAction; } ]
    else
      lib.optional (tool.stdinArgs != null) {
        external = {
          inherit (tool) command;
          arguments = tool.stdinArgsWith "{buffer_path}";
        };
      };

  # The servers of a language replace Zed's defaults, the universal ones serve the rest.
  mkLanguage =
    language:
    let
      formatter =
        lib.concatMap mkTool language.formatting
        ++ lib.optional (language.formatter.server != null) {
          language_server.name = zedName language.formatter.server;
        };
    in
    lib.optionalAttrs (language.servers != [ ]) {
      language_servers = map zedName language.servers ++ universal;
    }
    // lib.optionalAttrs (formatter != [ ]) { inherit formatter; };

  # Every declared language, so that Zed keeps their grammars while they are disabled.
  extensions =
    lib.concatMap (language: language.editors.zed.extensions) (lib.attrValues languages)
    ++ lib.remove null (lib.mapAttrsToList (_: server: server.editors.zed.extension) servers);
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  imports = [ ../shared/_editors ];

  options.custom.zed = {
    enable = lib.mkEnableOption "Zed";
    package = lib.mkPackageOption pkgs "zed-editor" { nullable = true; };
    settings = jsonOption "settings.json" { };
    keymap = jsonOption "keymap.json" [ ];
    tasks = jsonOption "tasks.json" [ ];
    debug = jsonOption "debug.json" [ ];
  };

  config = lib.mkIf cfg.enable {
    custom.zed.settings = {
      lsp = lib.mapAttrs' (
        _: server: lib.nameValuePair server.editors.zed.name (mkServer server)
      ) servers;
      auto_install_extensions = lib.genAttrs extensions (_: true);
      language_servers = universal;
      languages = lib.mapAttrs (_: mkLanguage) editors.zed;
    };

    home = {
      packages = lib.mkIf (cfg.package != null) [ cfg.package ];
      activation.setupZedFiles = lib'.mkMutableFiles {
        inherit config;
        files =
          lib.mapAttrsToList
            (name: value: {
              source = pkgs.writeText "zed-${name}.json" (builtins.toJSON value);
              target = "${config.xdg.configHome}/zed/${name}.json";
            })
            {
              inherit (cfg)
                debug
                keymap
                settings
                tasks
                ;
            };
      };
    };
  };
}
