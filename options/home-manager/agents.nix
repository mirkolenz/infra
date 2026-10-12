{ lib, ... }:
let
  inherit (lib) mkOption types;

  absolutePath = types.pathWith { absolute = true; };

  # an executable name, optionally followed by arguments
  command = types.strMatching "[A-Za-z0-9._+-]+( [^ ]+)*";

  listOption =
    elemType: description:
    mkOption {
      type = types.listOf elemType;
      default = [ ];
      inherit description;
    };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  # Shared agent configuration, read by the module of every agent that can express
  # it. Nothing here writes a file on its own, so an agent whose home-manager module
  # lacks the matching option stays unconfigured until it gains one.
  options.programs.agents = {
    enable = lib.mkEnableOption "the agents, run within nono with the shared sandbox";

    context = mkOption {
      type = with types; either lines path;
      default = "";
      example = lib.literalExpression "./AGENTS.md";
      description = "Shared instructions, either inline or as a markdown file, handed to every agent as its global context.";
    };

    skills = mkOption {
      type = with types; either (attrsOf (either lines path)) path;
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
      # Honoured by nono and every agent that sandboxes its network.
      # A leading `*.` matches subdomains only, a bare `*` every host.
      domains = {
        allow = listOption types.str "Hosts agents may reach.";
        deny = listOption types.str ''
          Hosts agents may not reach, winning over every allowed one,
          refused even when an agent would otherwise ask for them.
        '';
      };

      localhost = lib.mkEnableOption ''
        connecting to and listening on localhost, for local models and dev servers.
        nono on Linux matches ports but not addresses, so it opens the unprivileged ports
        to every host there, while the privileged ones, HTTP and HTTPS among them, stay with the proxy
      '';

      # Absolute paths, covering everything below.
      paths = {
        read = listOption absolutePath ''
          Paths agents may read, read-only even within a writable path, which only nono enforces.
        '';
        write = listOption absolutePath "Paths agents may read and write.";
        deny = listOption absolutePath ''
          Paths hidden from agents. nono on Linux refuses to start with one within a granted path.
        '';
      };

      # Paths relative to the workspaces, where `*` matches within a path segment and `**/` any directories.
      # Only nono enforces them, on macOS at any depth outside of temporary and writable absolute paths,
      # on Linux at the workspace roots and their git directories.
      workspace = {
        read = listOption types.str "Workspace paths agents may only read.";
        write = listOption types.str "Workspace paths exempt from a broader `read` or `deny` one.";
        deny = listOption types.str "Workspace paths hidden from agents.";
      };

      unixSockets = listOption types.str ''
        Unix sockets reachable from a sandbox, as the path it sees after symlink resolution.
        Everything else stays out of a subprocess' reach, under nono on Linux abstract sockets too.
      '';

      environment = {
        set = mkOption {
          type = with types; attrsOf str;
          default = { };
          example.ASTRO_TELEMETRY_DISABLED = "1";
          description = "Variables set for the agents and their subprocesses.";
        };
        unset = listOption types.str "Variables stripped from the agents and their subprocesses.";
      };

      # Matched as a prefix of a plain command line of the shell tool of an agent,
      # not within scripts, aliases or `sh -c`.
      commands = {
        allow = listOption command "Commands that agents run without asking.";
        deny = listOption command "Commands that agents refuse to run.";
      };
    };

    harnesses = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            launchers = mkOption {
              type = with types; attrsOf package;
              description = "Executables of the harness by name, each shadowed by a wrapper.";
            };

            sandboxArgs = mkOption {
              type = with types; listOf str;
              default = [ ];
              example = [ "--no-sandbox" ];
              description = "Arguments prepended to those of the harness, usually to disable its own sandbox.";
            };

            trailingSandboxArgs = mkOption {
              type = with types; listOf str;
              default = [ ];
              example = [ "--standalone" ];
              description = "Arguments appended to those of the harness, for flags its subcommands accept only after their name.";
            };

            addDirFlag = mkOption {
              type = with types; nullOr str;
              default = null;
              example = "--add-dir";
              description = "Flag of the harness that adds a workspace directory, passed for every `NONO_ALLOW` entry.";
            };

            # Granted like `programs.agents.sandbox.paths`, but within nono alone.
            paths = {
              read = listOption absolutePath ''
                Paths of the harness that it only reads within nono, such as the managed config
                within its state directories, which it would run outside of nono later.
              '';
              write = listOption absolutePath "Paths of the harness that it writes, such as its state and login.";
            };

            domains = listOption types.str "Hosts the harness itself talks to, reachable within nono.";

            unixSocketDirs = mkOption {
              type = with types; listOf str;
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
}
