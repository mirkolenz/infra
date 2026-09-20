{
  lib,
  lib',
  config,
  pkgs,
  ...
}:
let
  cfg = config.programs.agents;

  # https://agentskills.io/specification
  skillModule = {
    options = {
      description = lib.mkOption {
        type = lib.types.str;
        description = "What the skill does and when to use it; loaded eagerly by agents to decide activation.";
      };
      license = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      compatibility = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Environment requirements; only set when the skill needs specific tools, packages, or network access.";
      };
      allowedTools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Pre-approved tools, rendered as the experimental space-separated `allowed-tools` field.";
      };
      metadata = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
      text = lib.mkOption {
        type = lib.types.lines;
        description = "Markdown body of `SKILL.md` following the generated frontmatter.";
      };
    };
  };

  mkSkillMd =
    name: skill:
    lib'.mkMarkdown {
      body = skill.text;
      metadata = {
        inherit name;
        inherit (skill) description;
      }
      // lib.optionalAttrs (skill.license != null) { inherit (skill) license; }
      // lib.optionalAttrs (skill.compatibility != null) { inherit (skill) compatibility; }
      // lib.optionalAttrs (skill.allowedTools != [ ]) {
        allowed-tools = lib.concatStringsSep " " skill.allowedTools;
      }
      // lib.optionalAttrs (skill.metadata != { }) { inherit (skill) metadata; };
    };

  # Both forms of `skills` collapse to one directory holding a subdirectory per
  # skill, so every target gets the same single symlink. `types.path` also accepts
  # a derivation, which is an attribute set, hence the second test.
  skillsFile.source =
    if lib.isAttrs cfg.skills && !lib.isDerivation cfg.skills then
      pkgs.linkFarm "agent-skills" (
        lib.mapAttrs (name: skill: pkgs.writeTextDir "SKILL.md" (mkSkillMd name skill)) cfg.skills
      )
    else
      cfg.skills;

  # A literal source is linked as is, structured instructions are rendered once
  # and shared by every target.
  instructionsFile.source =
    if cfg.instructions.source != null then
      cfg.instructions.source
    else
      pkgs.writeText "AGENTS.md" cfg.instructions.text;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.agents = {
    enable = lib.mkEnableOption "agents";

    instructions = lib.mkOption {
      type = lib.types.nullOr lib'.mdFormat;
      default = null;
      description = "Shared instructions (AGENTS.md and equivalents) deployed to every configured agent.";
    };

    skills = lib.mkOption {
      type = with lib.types; either path (attrsOf (submodule skillModule));
      default = { };
      example = lib.literalExpression "./skills";
      description = ''
        Agent Skills (https://agentskills.io/specification) deployed to every configured
        agent, given either as a directory holding one ready-made skill directory per
        skill, or as an attribute set rendering each `SKILL.md` from the options below.
        The two forms are exclusive, so a skill that ships more than `SKILL.md` moves the
        whole set to the directory form.
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
      (lib.mkIf (cfg.instructions != null) {
        xdg.configFile = lib.genAttrs [
          "amp/AGENTS.md"
          "crush/CRUSH.md"
          "opencode/AGENTS.md"
        ] (_: instructionsFile);
        home.file = lib.genAttrs [
          ".claude/CLAUDE.md"
          ".codex/AGENTS.md"
          ".gemini/GEMINI.md"
          ".vibe/AGENTS.md"
        ] (_: instructionsFile);
      })
      (lib.mkIf (cfg.skills != { }) {
        xdg.configFile = lib.genAttrs [
          "agents/skills" # amp
          "opencode/skills"
        ] (_: skillsFile);
        home.file = lib.genAttrs [
          ".claude/skills"
          ".agents/skills" # codex
          ".gemini/skills"
          ".vibe/skills"
        ] (_: skillsFile);
      })
    ]
  );
}
