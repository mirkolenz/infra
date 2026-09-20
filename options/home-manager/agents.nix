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
  skillModule =
    { name, config, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.strMatching "[a-z0-9]+(-[a-z0-9]+)*";
          default = name;
          description = "Skill identifier; defaults to the attribute name and must match the skill directory name.";
        };
        source = lib.mkOption {
          type = lib.types.path;
          default = pkgs.writeTextDir "SKILL.md" (mkSkillMd config);
          description = "Skill directory holding `SKILL.md`; generated from the remaining options unless set to an existing directory.";
        };
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
    skill:
    lib'.mkMarkdown {
      body = skill.text;
      metadata = {
        inherit (skill) name description;
      }
      // lib.optionalAttrs (skill.license != null) { inherit (skill) license; }
      // lib.optionalAttrs (skill.compatibility != null) { inherit (skill) compatibility; }
      // lib.optionalAttrs (skill.allowedTools != [ ]) {
        allowed-tools = lib.concatStringsSep " " skill.allowedTools;
      }
      // lib.optionalAttrs (skill.metadata != { }) { inherit (skill) metadata; };
    };

  mkSkills =
    prefix:
    lib.mapAttrs' (
      name: skill: lib.nameValuePair "${prefix}/${name}" { inherit (skill) source; }
    ) cfg.skills;

  # A literal source ships its own frontmatter, so guard against the name it
  # declares drifting from the directory the skill is deployed to. Generated
  # sources are derivations, which cannot be read without import-from-derivation
  # and whose frontmatter is rendered from `name` anyway.
  mkSkillAssertion = name: skill: {
    assertion =
      lib.isDerivation skill.source
      || (
        lib.pathExists "${skill.source}/SKILL.md"
        && lib.hasInfix "\nname: ${name}\n" (lib.readFile "${skill.source}/SKILL.md")
      );
    message = "programs.agents.skills.${name}: source must be a directory whose SKILL.md declares `name: ${name}`.";
  };

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
      type = lib.types.attrsOf (lib.types.submodule skillModule);
      default = { };
      description = "Agent Skills (https://agentskills.io/specification) deployed to every configured agent.";
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
        assertions = lib.mapAttrsToList mkSkillAssertion cfg.skills;

        xdg.configFile = lib.mergeAttrsList (
          map mkSkills [
            "agents/skills" # amp
            "opencode/skills"
          ]
        );
        home.file = lib.mergeAttrsList (
          map mkSkills [
            ".claude/skills"
            ".agents/skills" # codex
            ".gemini/skills"
            ".vibe/skills"
          ]
        );
      })
    ]
  );
}
