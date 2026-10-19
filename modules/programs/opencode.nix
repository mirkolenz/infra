{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }@args:
    let
      llamaCpp = args.osConfig.services.llama-cpp or { enable = false; };
      agents = config.programs.agents;
      inherit (agents) sandbox;

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
    lib.mkIf config.programs.agents.enable {
      programs.opencode = {
        enable = true;
        package = pkgs.opencode-bin;
        inherit (agents) context skills;
        # https://opencode.ai/v2/docs/config
        settings = {
          share = "disabled";
          update = "disable";
          model = lib.mkIf llamaCpp.enable "llama-cpp/qwen3.6-35b-a3b";
          providers.llama-cpp = lib.mkIf llamaCpp.enable {
            name = "llama.cpp";
            package = "@opencode/ai/providers/openai-compatible";
            settings.baseURL = "http://127.0.0.1:${toString llamaCpp.settings.port}/v1";
            models."qwen3.6-35b-a3b".name = "Qwen 3.6 MoE";
          };
          # home-manager's `enableMcpIntegration` still renders the V1 shape
          mcp.servers = lib.mapAttrs (_: server: {
            type = "local";
            command = [ server.command ] ++ server.args or [ ];
          }) config.programs.mcp.servers;
          # https://opencode.ai/v2/docs/permissions
          # upstream allows `external_directory`, so paths outside the workspace need no rule
          permissions = mkRules "allow" "shell" (commandPatterns sandbox.commands.allow);
          # https://opencode.ai/v2/docs/policies
          # hard denies that neither an "Allow always" approval nor a project config lifts
          experimental.policies =
            mkRules "deny" "provider.use" [ "*" ]
            # the openai credential comes from `/connect`
            ++ mkRules "allow" "provider.use" [
              "llama-cpp"
              "openai"
            ]
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
