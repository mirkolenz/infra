{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
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
          permission.external_directory = {
            "/nix/store/**" = "allow";
            "${config.xdg.cacheHome}/**" = "allow";
            "${config.home.homeDirectory}/.npm/**" = "allow";
            # the ask default would only prompt, deny keeps the keys unreadable
            "${config.home.homeDirectory}/.ssh/**" = "deny";
          }
          # orb stores logs, sockets, and state here and reads them on every call, darwin only
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
            "${config.home.homeDirectory}/Library/Caches/**" = "allow";
            "${config.home.homeDirectory}/.orbstack/**" = "allow";
          };
        };
      };
      home.sessionVariables = {
        OPENCODE_EXPERIMENTAL = true;
      };
    };
}
