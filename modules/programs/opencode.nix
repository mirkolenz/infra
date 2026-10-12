{
  flake.modules.homeManager.default =
    {
      lib,
      lib',
      config,
      pkgs,
      ...
    }:
    let
      agents = config.programs.agents;
      sandbox = lib'.splitSandbox agents.sandbox;

      # `*` also matches `/`
      withContent = lib'.withContent "*";

      # a trailing ` *` matches the bare command as well
      commandPatterns = map (cmd: "${cmd} *");

      mkRules =
        effect: action:
        map (resource: {
          inherit action resource effect;
        });

      # resources are `<action>:<value>`
      denyRules = action: map (resource: "${action}:${resource}");

      llamaCppPort = 18000;
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
          model = "llama-cpp/qwen3.6-35b-a3b";
          providers.llama-cpp = {
            name = "llama.cpp";
            package = "@opencode/ai/providers/openai-compatible";
            settings.baseURL = "http://127.0.0.1:${toString llamaCppPort}/v1";
            models."qwen3.6-35b-a3b".name = "Qwen 3.6 MoE";
          };
          # home-manager's `enableMcpIntegration` still renders the V1 shape
          mcp.servers = lib.mapAttrs (_: server: {
            type = "local";
            command = [ server.command ] ++ server.args or [ ];
          }) config.programs.mcp.servers;
          # https://opencode.ai/v2/docs/permissions
          # upstream allows the workspace and asks for anything outside it
          permissions =
            mkRules "allow" "external_directory" (withContent (sandbox.readPaths ++ sandbox.writePaths))
            ++ mkRules "allow" "shell" (commandPatterns sandbox.allowedCommands);
          # https://opencode.ai/v2/docs/policies
          # hard denies that neither an "Allow always" approval nor a project config lifts
          experimental.policies =
            mkRules "deny" "provider.use" [ "*" ]
            # the openai credential comes from `/connect`
            ++ mkRules "allow" "provider.use" [
              "llama-cpp"
              "openai"
            ]
            ++ mkRules "deny" "permission" (
              # `*:` covers every path-based action
              denyRules "*" (withContent sandbox.deniedPaths)
              ++ denyRules "edit" (withContent sandbox.readPaths)
              ++ denyRules "shell" (commandPatterns sandbox.deniedCommands)
            );
        };
      };
      programs.agents = {
        harnesses.opencode = {
          launchers.opencode = config.programs.opencode.package;
          # A private server runs inside nono, the background service would not.
          sandboxArgs = [ "--standalone" ];
          # the `/connect` logins are kept in the database below `dataHome`
          stateDirs = [
            "${config.xdg.configHome}/opencode"
            "${config.xdg.dataHome}/opencode"
            "${config.xdg.dataHome}/opentui"
            "${config.xdg.stateHome}/opencode"
            "${config.home.homeDirectory}/.opencode"
          ];
          # every plugin runs outside of nono as well
          protectedEntries = [
            "AGENTS.md"
            "opencode.json"
            "plugins"
            "skills"
          ];
          domains = [
            "api.openai.com"
            "auth.openai.com"
            "chatgpt.com"
            "models.dev"
          ];
        };
        # The project config, every plugin there runs outside of nono as well, except for the prompts.
        sandbox.paths = {
          ".opencode" = "read";
          # singular and plural names
          ".opencode/agent*" = "write";
          ".opencode/command*" = "write";
          ".opencode/mode*" = "write";
          ".opencode/skill*" = "write";
          "opencode.json*" = "read";
        };
      };
      # llama.cpp, loopback is already in `NO_PROXY`
      programs.nono.profiles.agents.network.open_port = [ llamaCppPort ];
    };
}
