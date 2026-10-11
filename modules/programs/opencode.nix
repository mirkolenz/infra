{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      agents = config.programs.agents;

      # `*` also matches `/`
      pathsWith =
        access:
        map (path: "${path}/*") (lib.attrNames (lib.filterAttrs (_: a: a == access) agents.sandbox.paths));

      mkRules =
        effect: action:
        map (resource: {
          inherit action resource effect;
        });
    in
    lib.mkIf config.custom.features.extras.enable {
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
            settings.baseURL = "http://127.0.0.1:18000/v1";
            models."qwen3.6-35b-a3b".name = "Qwen 3.6 MoE";
          };
          # home-manager's `enableMcpIntegration` still renders the V1 shape
          mcp.servers = lib.mapAttrs (_: server: {
            type = "local";
            command = [ server.command ] ++ server.args or [ ];
          }) config.programs.mcp.servers;
          # https://opencode.ai/v2/docs/permissions
          # upstream allows the workspace and asks for anything outside it
          permissions = mkRules "allow" "external_directory" (pathsWith "read" ++ pathsWith "write");
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
              # resources are `<action>:<value>`, so `*:` covers every path-based action
              map (path: "*:${path}") (pathsWith "deny")
              ++ map (path: "edit:${path}") (pathsWith "read")
              ++ map (cmd: "shell:${cmd} *") agents.sandbox.deniedCommands
            );
        };
      };
    };
}
