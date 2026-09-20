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

      mkGlob = path: "${path}/**";
    in
    lib.mkIf config.custom.features.extras.enable {
      programs.opencode = {
        enable = true;
        package = pkgs.opencode-bin;
        enableMcpIntegration = true;
        # https://opencode.ai/docs/config/
        settings = {
          share = "disabled";
          autoupdate = false;
          model = "llama-cpp/qwen3.6-35b-a3b";
          # exclusive allowlist, so providers are never auto-loaded from stray env vars
          enabled_providers = [
            "llama-cpp"
            "openai"
          ];
          # the openai key comes from `opencode auth login`, no provider entry needed
          provider = {
            llama-cpp = {
              npm = "@ai-sdk/openai-compatible";
              name = "llama.cpp";
              options.baseURL = "http://127.0.0.1:18000/v1";
              models = {
                "qwen3.6-35b-a3b".name = "Qwen 3.6 MoE";
              };
            };
          };
          # https://opencode.ai/docs/permissions/
          # everything else keeps the upstream defaults, which allow the workspace
          # tools and ask for anything outside it. within a tool the last matching
          # rule wins, so use lib.hm.dag.entryAfter when order matters.
          # opencode draws no line between reading and writing outside the workspace,
          # and its ask default would only prompt, so deny is what keeps keys unreadable.
          permission.external_directory = lib.mapAttrs' (
            path: access: lib.nameValuePair (mkGlob path) (if access == "deny" then "deny" else "allow")
          ) agents.sandbox.paths;
        };
      };
      home.sessionVariables = {
        OPENCODE_EXPERIMENTAL = true;
      };
    };
}
