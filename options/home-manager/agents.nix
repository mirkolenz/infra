{
  lib,
  lib',
  config,
  ...
}:
let
  cfg = config.programs.agents;

  # https://agentskills.io/specification
  skillModule =
    { name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.strMatching "[a-z0-9]+(-[a-z0-9]+)*";
          default = name;
          description = "Skill identifier; defaults to the attribute name and must match the skill directory name.";
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
        files = lib.mkOption {
          type = lib.types.attrsOf lib.types.lines;
          default = { };
          description = "Additional text files relative to the skill root, e.g. `references/REFERENCE.md` or `scripts/run.sh`.";
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

  mkSkillFiles =
    prefix:
    lib.concatMapAttrs (
      dir: skill:
      {
        "${prefix}/${dir}/SKILL.md".text = mkSkillMd skill;
      }
      // lib.mapAttrs' (
        file: content: lib.nameValuePair "${prefix}/${dir}/${file}" { text = content; }
      ) skill.files
    ) cfg.skills;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.agents = {
    enable = lib.mkEnableOption "agents";

    instructions = lib.mkOption {
      type = lib'.mdFormat;
      default = { };
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
      (lib.mkIf (cfg.instructions.text != "") {
        xdg.configFile = {
          "amp/AGENTS.md".text = cfg.instructions.text;
          "crush/CRUSH.md".text = cfg.instructions.text;
          "opencode/AGENTS.md".text = cfg.instructions.text;
        };
        home.file = {
          ".claude/CLAUDE.md".text = cfg.instructions.text;
          ".codex/AGENTS.md".text = cfg.instructions.text;
          ".gemini/GEMINI.md".text = cfg.instructions.text;
          ".vibe/AGENTS.md".text = cfg.instructions.text;
        };
      })
      (lib.mkIf (cfg.skills != { }) {
        xdg.configFile = lib.mergeAttrsList (
          map mkSkillFiles [
            "agents/skills" # amp
            "opencode/skills"
          ]
        );
        home.file = lib.mergeAttrsList (
          map mkSkillFiles [
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
