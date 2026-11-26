{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      # the request body for a level of reasoning effort of a chat template
      reasoning = effort: { chat_template_kwargs.reasoning_effort = effort; };

      agents = config.programs.agents;
      inherit (agents) sandbox;
      inherit (agents.providers) pythia;
      pythiaQwen = "${pythia.name}/${pythia.models."qwen3.8-27b".name}";

      # Each of `paths` followed by its content, since resources match the whole path.
      # `*` also matches `/`.
      withContent = lib.concatMap (path: [
        path
        "${path}/*"
      ]);

      # a trailing ` *` matches the bare command as well
      commandPatterns = map (cmd: "${cmd} *");

      mkRules =
        effect: action:
        map (resource: {
          inherit action resource effect;
        });

      # resources are `<action>:<value>`
      denyRules = action: map (resource: "${action}:${resource}");
    in
    lib.mkIf agents.enable {
      programs.opencode = {
        enable = true;
        package = pkgs.opencode-bin;
        inherit (agents) context skills;
        # https://opencode.ai/v2/docs/config
        settings = {
          share = "disabled";
          update = "disable";
          # `provider/model#variant`, the ChatGPT login comes from `/connect`
          model = "openai/gpt-6.2-sol#high";
          # https://opencode.ai/v2/docs/agents#built-ins
          # There is no global subagent model, every other agent inherits the model of its session.
          # `compaction` stays with the session, since its context may exceed the one of the subagents.
          agents = lib.optionalAttrs (agents.providers ? pythia) {
            explore.model = pythiaQwen;
            general.model = pythiaQwen;
            summary.model = "${pythiaQwen}#low";
            title.model = "${pythiaQwen}#low";
          };
          providers = lib.mapAttrs' (
            _: provider:
            lib.nameValuePair provider.name {
              name = provider.label;
              package = "@opencode/ai/providers/openai-compatible";
              settings.baseURL = "${provider.url}/v1";
              models = lib.mapAttrs' (
                _: model:
                lib.nameValuePair model.name {
                  name = model.label;
                  # Without limits, opencode assumes 200K and 32K for models outside the catalog.
                  limit = { inherit (model) context output; };
                  body = lib.optionalAttrs (model.effort != null) (reasoning model.effort);
                  variants = map (id: {
                    inherit id;
                    body = reasoning id;
                  }) model.efforts;
                }
              ) provider.models;
            }
          ) agents.providers;
          # https://opencode.ai/v2/docs/permissions
          # upstream allows `external_directory`, so paths outside the workspace need no rule
          permissions = mkRules "allow" "shell" (commandPatterns sandbox.commands.allow);
          # https://opencode.ai/v2/docs/policies
          # hard denies that neither an "Allow always" approval nor a project config lifts
          experimental.policies =
            mkRules "deny" "provider.use" [ "*" ]
            ++ mkRules "allow" "provider.use" (
              [ "openai" ] ++ lib.catAttrs "name" (lib.attrValues agents.providers)
            )
            ++ mkRules "deny" "tool.use" (
              # `*:` covers every path-based action
              denyRules "*" (withContent sandbox.paths.deny)
              ++ denyRules "edit" (withContent sandbox.paths.read)
              ++ denyRules "shell" (commandPatterns sandbox.commands.deny)
            );
        };
      };
      programs.agents = {
        harnesses.opencode = {
          launchers.opencode = config.programs.opencode.package;
          # A private server runs inside nono, the background service would not.
          # Subcommands take the flag only after their name, `mcp`, `serve` and `service` not at all.
          trailingSandboxArgs = [ "--standalone" ];
          paths.write = [
            "${config.xdg.configHome}/opencode"
            # the `/connect` logins are kept in the database here
            "${config.xdg.dataHome}/opencode"
            "${config.xdg.dataHome}/opentui"
            "${config.xdg.stateHome}/opencode"
            "${config.home.homeDirectory}/.opencode"
          ];
          # Every plugin runs outside of nono as well, and the background service gets the `env` of `service.json`.
          # The config search outside of nono reaches the home directory too.
          paths.read = [
            "${config.xdg.configHome}/opencode/AGENTS.md"
            "${config.xdg.configHome}/opencode/opencode.json"
            "${config.xdg.configHome}/opencode/plugins"
            "${config.xdg.configHome}/opencode/service.json"
            "${config.xdg.configHome}/opencode/skills"
            "${config.home.homeDirectory}/.opencode/AGENTS.md"
            "${config.home.homeDirectory}/.opencode/opencode.json"
            "${config.home.homeDirectory}/.opencode/plugins"
            "${config.home.homeDirectory}/.opencode/skills"
          ];
          domains = [
            "api.openai.com"
            "auth.openai.com"
            "chatgpt.com"
            "models.opencode.ai"
          ];
        };
        # The project config, every plugin there runs outside of nono as well, except for the prompts.
        sandbox.workspace.read = [
          ".opencode"
          "opencode.json*"
        ];
        # singular and plural names
        sandbox.workspace.write = [
          ".opencode/agent*"
          ".opencode/command*"
          ".opencode/mode*"
          ".opencode/skill*"
        ];
      };
      programs.nono.profiles.agents = {
        # The project config search opens every parent up to `/`, which nono keeps unreadable on Linux,
        # and a config found there stays unreadable on macOS.
        environment.set_vars.OPENCODE_DISABLE_PROJECT_CONFIG = "1";
      };
    };
}
