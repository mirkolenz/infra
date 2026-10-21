# Languages with their language servers, fixers and formatters, defined by the generic module
# `flake.modules.generic.languages` of modules/programs/languages and shared by home-manager
# and the standalone nixvim build and treefmt. The integrations of options/home-manager,
# options/nixvim and options/treefmt map them onto the editors, coding agents and treefmt,
# with the options of each editor in ./<editor>.nix.
# The leading underscore hides this declaration from import-tree.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.custom;
  jsonType = (pkgs.formats.json { }).type;
  serverName = types.enum (lib.attrNames cfg.lsp.servers);
  toolName = types.enum (lib.attrNames cfg.tools);

  # The modules of the languages, servers and tools that each editor adds its options with.
  editors = lib.genAttrs [ "fresh" "neovim" "zed" ] (
    editor: import ./${editor}.nix { inherit lib jsonType; }
  );
  entries =
    kind: module:
    types.submoduleWith {
      modules = [ module ] ++ lib.catAttrs kind (lib.attrValues editors);
    };

  enabled = lib.filterAttrs (_: language: language.enable) cfg.languages;
  enabledWith = predicate: lib.attrNames (lib.filterAttrs (_: predicate) enabled);

  derived =
    type: description: default:
    mkOption {
      inherit type description default;
      readOnly = true;
    };

  # The options of every server and tool.
  executable =
    { config, ... }:
    {
      options = {
        package = mkOption {
          type = types.package;
          description = "Package providing the executable.";
        };

        command = mkOption {
          type = types.str;
          default = lib.getExe config.package;
          defaultText = lib.literalExpression "lib.getExe package";
          description = "Path of the executable, which every editor runs.";
        };

        args = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = "Arguments of the executable, which a tool follows with the paths of the files it changes in place.";
        };
      };
    };

  registry =
    kind: description: module:
    mkOption {
      type = types.attrsOf (
        entries kind {
          imports = [
            executable
            module
          ];
        }
      );
      default = { };
      inherit description;
    };

  server =
    { name, config, ... }:
    {
      options = {
        settings = mkOption {
          type = jsonType;
          default = { };
          example.ty.diagnosticMode = "workspace";
          description = "Workspace configuration, keyed by the section the server requests.";
        };

        initializationOptions = mkOption {
          type = jsonType;
          default = { };
          description = "Options sent along with the initialize request.";
        };

        linter = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether the server only lints, limited to diagnostics and their code actions in the
            editors that can, leaving every other feature to the other servers of a language.
          '';
        };

        languages = derived (with types; listOf str) "Enabled languages that the server serves." (
          enabledWith (language: lib.elem name language.servers)
        );

        formats = derived types.bool "Whether the server formats an enabled language." (
          enabledWith (language: language.formatter.server == name) != [ ]
        );

        active = derived types.bool "Whether the server serves an enabled language or every one." (
          config.languages != [ ] || lib.elem name cfg.universal.servers
        );
      };
    };

  tool =
    { name, config, ... }:
    {
      options = {
        stdinArgs = mkOption {
          type = with types; nullOr (listOf str);
          default = null;
          example = [
            "--stdin-filepath"
            "{file}"
          ];
          description = ''
            Arguments with which the tool reads the file from stdin and writes it to stdout instead,
            where an argument `{file}` stands for its path, or `null` without such a mode.
          '';
        };

        stdinArgsWith = mkOption {
          type = with types; functionTo (listOf str);
          default = file: map (arg: if arg == "{file}" then file else arg) config.stdinArgs;
          readOnly = true;
          internal = true;
          description = "The stdin arguments, with `{file}` replaced by the placeholder of an editor.";
        };

        linter = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether the tool only reports problems, which the editors take from the language
            servers instead, so that only the coding agents and treefmt run it.
          '';
        };

        active = derived types.bool "Whether an enabled language fixes or formats with the tool." (
          enabledWith (language: lib.elem name language.tools) != [ ]
        );
      };
    };

  language =
    { name, config, ... }:
    {
      options = {
        enable = lib.mkEnableOption "the language ${name}" // {
          default = cfg.features.extras.enable;
          defaultText = lib.literalExpression "config.custom.features.extras.enable";
        };

        files = mkOption {
          type = with types; listOf str;
          default = [ ];
          example = [
            "Dockerfile"
            "*.dockerfile"
          ];
          description = ''
            Files of the language: exact names, extensions such as `*.py`, or paths relative to the
            root of the repository, where `*` stands for any name and `**` for any directories.
          '';
        };

        servers = mkOption {
          type = types.listOf serverName;
          default = [ ];
          description = "Language servers of the language, by priority.";
        };

        fixers = mkOption {
          type = types.listOf toolName;
          default = [ ];
          example = [ "ruff_fix" ];
          description = "Tools that fix or check the files before they get formatted, in this order.";
        };

        formatter = {
          server = mkOption {
            type = with types; nullOr (enum config.servers);
            default = null;
            description = "Language server that formats the language in the editors.";
          };

          tool = mkOption {
            type = types.nullOr toolName;
            default = null;
            description = ''
              Tool that formats the language for the coding agents, with the same output as the
              server, and in the editors without a server.
            '';
          };
        };

        extensions = derived (with types; listOf str) "Extensions of the files, with their leading dot." (
          map (lib.removePrefix "*") (
            lib.filter (file: lib.hasPrefix "*." file && !lib.hasInfix "/" file) config.files
          )
        );

        tools =
          derived (types.listOf toolName)
            ''
              Tools that fix and format the language, in this order: the universal fixers, its own,
              and its formatter.
            ''
            (
              cfg.universal.fixers
              ++ config.fixers
              ++ lib.optional (config.formatter.tool != null) config.formatter.tool
            );

        formatting =
          derived (types.listOf toolName)
            "Tools that format the language in the editors, without the linters and the formatter of a formatting server."
            (
              lib.filter (
                tool:
                !cfg.tools.${tool}.linter && !(config.formatter.server != null && tool == config.formatter.tool)
              ) config.tools
            );
      };
    };

  merge =
    group:
    lib.head group
    // {
      servers = lib.unique (lib.concatMap (language: language.servers) group);
    };
  byEditor =
    editor:
    lib.mapAttrs (_: merge) (
      lib.zipAttrs (
        lib.mapAttrsToList (
          _: language: lib.genAttrs language.editors.${editor}.names (_: language)
        ) enabled
      )
    );
in
{
  imports = [ ../features.nix ];

  options.custom = {
    languages = mkOption {
      type = types.attrsOf (entries "language" language);
      default = { };
      description = ''
        Languages, keyed by their LSP language identifier.
        Most belong to the extras, so they are enabled along with them.
      '';
    };

    lsp.servers = registry "server" ''
      Language servers, keyed by their nvim-lspconfig name.
      They are active while an enabled language refers to them.
    '' server;

    # The servers and tools of every language, along with its own.
    universal = {
      servers = mkOption {
        type = types.listOf serverName;
        default = [ ];
        example = [ "harper_ls" ];
        description = "Language servers of every language.";
      };

      fixers = mkOption {
        type = types.listOf toolName;
        default = [ ];
        example = [ "keep-sorted" ];
        description = "Tools that fix every file before its own fixers, in this order.";
      };
    };

    tools = registry "tool" ''
      Fixers and formatters, keyed by their conform.nvim name, which treat any exit code
      but 0 as a failure, remaining lints included.
      They are active while an enabled language or the universal fixers refer to them.
    '' tool;

    active = mkOption {
      type = with types; attrsOf (attrsOf raw);
      readOnly = true;
      internal = true;
      description = "The enabled languages and the active servers and tools.";
      default = {
        languages = enabled;
        servers = lib.filterAttrs (_: server: server.active) cfg.lsp.servers;
        tools = lib.filterAttrs (_: tool: tool.active) cfg.tools;
      };
    };

    editors = mkOption {
      type = with types; attrsOf (attrsOf raw);
      readOnly = true;
      internal = true;
      description = ''
        The enabled languages of each editor, keyed by the languages of the editor,
        where the languages that share one merge into the first, with all their servers.
      '';
      default = lib.genAttrs (lib.attrNames editors) byEditor;
    };
  };
}
