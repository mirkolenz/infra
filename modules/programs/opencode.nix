{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.withOptionals {
      programs.opencode = {
        enable = true;
        package = pkgs.opencode-bin;
        # https://opencode.ai/docs/config/
        settings = {
          share = "disabled";
          autoupdate = false;
          model = "lmstudio/zai-org/glm-4.7-flash";
          provider = {
            lmstudio = {
              npm = "@ai-sdk/openai-compatible";
              name = "LM Studio";
              options.baseURL = "http://127.0.0.1:1234/v1";
              models = {
                "openai/gpt-oss-20b" = {
                  name = "OpenAI GPT OSS";
                };
                "zai-org/glm-4.7-flash" = {
                  name = "GLM 4.7 Flash";
                };
                "qwen/qwen3.5-35b-a3b" = {
                  name = "Qwen 3.5 MoE";
                };
              };
            };
          };
        };
      };
      home.sessionVariables = {
        OPENCODE_EXPERIMENTAL = true;
      };
    };
}
