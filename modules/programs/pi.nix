{ lib', ... }:
{
  flake.modules.homeManager.default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      agents = config.programs.agents;
      cfg = config.programs.pi-coding-agent;

      # The thinking levels of pi are the efforts, where `off` stands for `none`.
      toLevel = effort: if effort == "none" then "off" else effort;

      # https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models-configuration.md
      mkModel =
        model:
        {
          id = model.name;
          name = model.label;
          contextWindow = model.context;
          maxTokens = model.output;
        }
        // lib.optionalAttrs (model.efforts != [ ]) {
          reasoning = true;
          # null hides a level, every one left out would get the default of pi
          thinkingLevelMap = lib.listToAttrs (
            map (
              effort: lib.nameValuePair (toLevel effort) (if lib.elem effort model.efforts then effort else null)
            ) lib'.reasoningEfforts
          );
          compat = {
            thinkingFormat = "chat-template";
            supportsReasoningEffort = false;
            chatTemplateKwargs.reasoning_effort."$var" = "thinking.effort";
          };
        };

      # the startup level of every provider model with a default effort
      providerThinkingLevels = lib.concatMapAttrs (
        _: provider:
        lib.concatMapAttrs (
          _: model:
          lib.optionalAttrs (model.effort != null) {
            "${provider.name}/${model.name}" = toLevel model.effort;
          }
        ) provider.models
      ) agents.providers;

      # pi has no subagents of its own, the example extension spawns a pi process for each agent in `agents/`
      hasSubagents = agents.providers ? pythia;
      inherit (agents.providers) pythia;
      subagentModel = "${pythia.name}/${pythia.models."qwen3.8-27b".name}";

      # A subagent of the example extension, as markdown with a frontmatter, where JSON is valid YAML.
      agentFile = frontmatter: prompt: {
        text = ''
          ---
          ${lib.toJSON frontmatter}
          ---

          ${prompt}
        '';
      };
    in
    lib.mkIf agents.enable {
      programs.pi-coding-agent = {
        enable = true;
        package = pkgs.pi-agent-bin;
        inherit (agents) context;
        # https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/settings.md
        settings = {
          enableInstallTelemetry = false;
          # the ChatGPT login comes from `/login openai`
          defaultProvider = "openai";
          defaultModel = "gpt-6.2-sol";
          modelThinkingLevels = providerThinkingLevels // {
            "openai/gpt-6.2-sol" = "high";
          };
          extensions = lib.optional hasSubagents "${cfg.package}/libexec/examples/extensions/subagent";
        };
        # Unlike its built-in llama.cpp provider, a plain one needs no login.
        models.providers = lib.mapAttrs' (
          _: provider:
          lib.nameValuePair provider.name {
            name = provider.label;
            baseUrl = "${provider.url}/v1";
            api = "openai-completions";
            # makes the models available, the servers take no key
            apiKey = "none";
            models = map mkModel (lib.attrValues provider.models);
          }
        ) agents.providers;
      };
      # the upstream module has no option for the skills, the subagents, or the version check
      home.file =
        lib'.mkAgentSkills ".pi/agent/skills" agents.skills
        # mirroring the built-in subagents of opencode
        // lib.optionalAttrs hasSubagents {
          "${cfg.configDir}/agents/explore.md" =
            agentFile
              {
                name = "explore";
                description = "Fast read-only exploration of a codebase, returning compressed findings";
                model = subagentModel;
                tools = [
                  "read"
                  "grep"
                  "find"
                  "ls"
                  "bash"
                ];
              }
              ''
                You explore a codebase without changing it, using bash only for read-only commands.
                Return the relevant files, symbols, and findings compactly, since the caller has not seen them.
              '';
          "${cfg.configDir}/agents/general.md" =
            agentFile
              {
                name = "general";
                description = "General-purpose agent for multi-step tasks within an isolated context";
                model = subagentModel;
              }
              ''
                You complete the delegated task autonomously.
                Finish with a concise summary of what you did and found, naming every changed file.
              '';
        };
      home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";
      programs.agents = {
        # pi has no sandbox of its own and no flag for extra directories
        harnesses.pi = {
          launchers.pi = cfg.package;
          # the sessions and the provider logins
          paths.write = [ cfg.configDir ];
          paths.read = [
            "${cfg.configDir}/AGENTS.md"
            "${cfg.configDir}/agents"
            "${cfg.configDir}/models.json"
            "${cfg.configDir}/settings.json"
            "${cfg.configDir}/skills"
          ];
          domains = [
            # the model catalog
            "pi.dev"
            # the subscription providers that the claude and codex harnesses use as well
            "api.anthropic.com"
            "claude.ai"
            "platform.claude.com"
            "api.openai.com"
            "auth.openai.com"
            "chatgpt.com"
          ];
        };
        # The project settings and resources load only after the project is trusted.
        sandbox.workspace.read = [ ".pi" ];
      };
    };
}
