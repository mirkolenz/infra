{
  lib,
  config,
  ...
}:
let
  cfg = config.programs.agents;

  mkFiles = attrs: targets: lib.genAttrs targets (_: attrs);

  instructions = mkFiles { source = cfg.instructions.source; };

  # Linked file by file so each target stays a real directory. A single directory
  # symlink would put every skill inside the store, and an entry another module adds
  # next to them, such as the personal plugin that `programs.claude-code` generates,
  # would then resolve outside $HOME.
  skills = mkFiles {
    source = cfg.skills.source;
    recursive = true;
  };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.agents = {
    enable = lib.mkEnableOption "agents";

    instructions.source = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "./AGENTS.md";
      description = "Path to a markdown file with shared instructions, deployed to every configured agent as AGENTS.md and its equivalents.";
    };

    skills.source = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "./skills";
      description = ''
        Path to a directory of Agent Skills (https://agentskills.io/specification), holding
        one directory per skill, each with its own `SKILL.md`, deployed to every configured
        agent.
      '';
    };

    sandbox = {
      allowedDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "*.githubusercontent.com" ];
        description = ''
          Hosts agents may reach, honoured by every agent that sandboxes its network. A
          leading `*.` matches subdomains only, so an apex that is itself contacted has
          to be listed on its own.
        '';
      };

      deniedDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "pypi.org" ];
        description = ''
          Hosts agents may not reach, overriding `allowedDomains`. A deny is stronger
          than an omission: an agent that can otherwise ask for an unforeseen host, or
          name one per command, is refused these without a prompt.
        '';
      };

      paths = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.enum [
            "read"
            "write"
            "deny"
          ]
        );
        default = { };
        example = {
          "/nix" = "read";
          "~/.ssh" = "deny";
        };
        description = ''
          Directories outside the workspace and the access agents get to them. An agent
          that confines reads enforces `read` as its allowlist; one that reads freely by
          default only pre-approves its permission prompt with it. `deny` is enforced
          either way and overrides the other two.
        '';
      };

      allowedUnixSockets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Unix sockets reachable from a sandbox, given as the path a sandbox sees after
          symlink resolution. Everything absent is a socket an escaped process cannot
          reach, so this list is what keeps agent sockets out of a subprocess' hands.
        '';
      };

      deniedEnvVars = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "SSH_AUTH_SOCK" ];
        description = "Variables stripped from the environment agents hand to a subprocess.";
      };

      sessionVariables = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = ''
          Variables set in the environment agents hand to a subprocess. Values are
          strings because that is what every agent writes into a process environment,
          whatever its own config format would allow.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (cfg.instructions.source != null) {
        xdg.configFile = instructions [
          "amp/AGENTS.md"
          "crush/CRUSH.md"
          "opencode/AGENTS.md"
        ];
        home.file = instructions [
          ".claude/CLAUDE.md"
          ".codex/AGENTS.md"
          ".gemini/GEMINI.md"
          ".vibe/AGENTS.md"
        ];
      })
      (lib.mkIf (cfg.skills.source != null) {
        xdg.configFile = skills [
          "agents/skills" # amp
          "opencode/skills"
        ];
        home.file = skills [
          ".claude/skills"
          ".agents/skills" # codex
          ".gemini/skills"
          ".vibe/skills"
        ];
      })
    ]
  );
}
