{
  config,
  lib,
  lib',
  ...
}:
let
  inherit (lib') namesWithValue;

  sandbox = config.programs.agents.sandbox;
  absolute = lib.filterAttrs (key: _: lib.hasPrefix "/" key) sandbox.paths;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  # Shared agent configuration, read by the module of every agent that can express
  # it. Nothing here writes a file on its own, so an agent whose home-manager module
  # lacks the matching option stays unconfigured until it gains one.
  options.programs.agents = {
    enable = lib.mkEnableOption "the agents, run within nono with the shared sandbox";

    context = lib.mkOption {
      type = with lib.types; either lines path;
      default = "";
      example = lib.literalExpression "./AGENTS.md";
      description = "Shared instructions, either inline or as a markdown file, handed to every agent as its global context.";
    };

    skills = lib.mkOption {
      type = with lib.types; either (attrsOf (either lines path)) path;
      default = { };
      example = lib.literalExpression "./skills";
      description = ''
        Agent Skills (https://agentskills.io/specification), handed to every agent,
        either a directory holding one directory per skill or an attribute set keyed by
        skill name. An attribute is a directory of its own, a single `SKILL.md`, or that
        file's content inline.
      '';
    };

    sandbox = {
      domains = lib.mkOption {
        type =
          with lib.types;
          attrsOf (enum [
            "allow"
            "deny"
          ]);
        default = { };
        example = {
          "*.githubusercontent.com" = "allow";
          "pypi.org" = "deny";
        };
        description = ''
          Hosts agents may (`allow`) or may not (`deny`) reach, honoured by nono and every agent
          that sandboxes its network. A leading `*.` matches subdomains only, a bare `*` every host.
          A deny wins over every allow and also refuses a host that an agent would otherwise ask for.
        '';
      };

      localhost = lib.mkEnableOption ''
        connecting to and listening on localhost, for local models and dev servers.
        nono on Linux matches ports but not addresses, so it opens the unprivileged ports
        to every host there, while the privileged ones, HTTP and HTTPS among them, stay with the proxy
      '';

      paths = lib.mkOption {
        type =
          with lib.types;
          attrsOf (enum [
            "read"
            "write"
            "deny"
          ]);
        default = { };
        example = {
          "/nix" = "read";
          "/home/user/.ssh" = "deny";
          ".env.*" = "deny";
          ".env.example" = "write";
        };
        description = ''
          Paths and the access agents get to them, covering everything below. An absolute key
          is granted (`read`, `write`) or hidden (`deny`), and `read` stays read-only within a
          writable directory. Other keys are relative, where `*` matches within a path segment
          and `**/` any directories, `read` and `deny` restrict the path, and `write` exempts it
          from a broader relative key. Only nono enforces relative keys, on macOS at any depth
          outside of temporary and writable absolute paths, on Linux at the workspace roots
          and their git directories.
        '';
      };

      unixSockets = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        description = ''
          Unix sockets reachable from a sandbox, as the path it sees after symlink resolution.
          Everything else stays out of a subprocess' reach, under nono on Linux abstract sockets too.
        '';
      };

      environment = lib.mkOption {
        type = with lib.types; attrsOf (nullOr str);
        default = { };
        example = {
          SSH_AUTH_SOCK = null;
          ASTRO_TELEMETRY_DISABLED = "1";
        };
        description = ''
          Variables set for the agents and their subprocesses, or stripped when `null`.
        '';
      };

      commands = lib.mkOption {
        # an executable name, optionally followed by arguments
        type =
          with lib.types;
          addCheck
            (attrsOf (enum [
              "allow"
              "deny"
            ]))
            (
              commands:
              lib.all (name: lib.match "[A-Za-z0-9._+-]+( [^ ]+)*" name != null) (lib.attrNames commands)
            );
        default = { };
        example = {
          jq = "allow";
          "gh auth token" = "deny";
        };
        description = ''
          Commands that agents run without asking (`allow`) or refuse (`deny`), an executable
          name optionally followed by arguments, matched as a prefix of a plain command line of
          their shell tool, not within scripts, aliases or `sh -c`.
        '';
      };

      resolved = lib.mkOption {
        type = with lib.types; lazyAttrsOf (either (listOf str) (attrsOf str));
        readOnly = true;
        internal = true;
        description = ''
          The other options split for the modules translating them, `paths` into the `absolute`
          and `relative` ones and the absolute ones by access, `environment` into the variables
          to `set` and `unset`, and `domains` and `commands` by access.
        '';
      };
    };

    harnesses = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            launchers = lib.mkOption {
              type = with lib.types; attrsOf package;
              description = "Executables of the harness by name, each shadowed by a wrapper.";
            };

            sandboxArgs = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
              example = [ "--no-sandbox" ];
              description = "Arguments prepended to those of the harness, usually to disable its own sandbox.";
            };

            trailingSandboxArgs = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
              example = [ "--standalone" ];
              description = "Arguments appended to those of the harness, for flags its subcommands accept only after their name.";
            };

            addDirFlag = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              example = "--add-dir";
              description = "Flag of the harness that adds a workspace directory, passed for every `NONO_ALLOW` entry.";
            };

            stateDirs = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
              description = "Directories holding the state and login of the harness, writable within nono.";
            };

            protectedEntries = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
              description = ''
                Entries of every one of `stateDirs` that agents may only read, the managed config
                and everything else the harness would run outside of nono later.
              '';
            };

            domains = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
              description = "Hosts the harness itself talks to, reachable within nono.";
            };

            unixSocketDirs = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
              example = [ "/tmp/codex-browser-use" ];
              description = ''
                Directories whose sockets the harness connects to within nono, such as those
                of a desktop app it drives, skipped while missing.
              '';
            };
          };
        }
      );
      default = { };
      description = ''
        Agent harnesses, whose launchers are shadowed by commands running them inside `nono run`
        with the profile of `NONO_PROFILE`, or directly inside nono.
        The directories of the comma-separated `NONO_ALLOW` are granted by nono and passed
        to the harness through its `addDirFlag`.
      '';
    };
  };

  config.programs.agents.sandbox.resolved = {
    inherit absolute;
    relative = lib.filterAttrs (key: _: !lib.hasPrefix "/" key) sandbox.paths;
    readPaths = namesWithValue "read" absolute;
    writePaths = namesWithValue "write" absolute;
    deniedPaths = namesWithValue "deny" absolute;
    set = lib.filterAttrs (_: value: value != null) sandbox.environment;
    unset = namesWithValue null sandbox.environment;
    allowedDomains = namesWithValue "allow" sandbox.domains;
    deniedDomains = namesWithValue "deny" sandbox.domains;
    allowedCommands = namesWithValue "allow" sandbox.commands;
    deniedCommands = namesWithValue "deny" sandbox.commands;
  };
}
