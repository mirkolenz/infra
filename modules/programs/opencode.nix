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
        # https://opencode.ai/docs/config/
        settings = {
          share = "disabled";
          autoupdate = false;
          model = "llama-cpp/qwen3.6-35b-a3b";
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
        };
      };
      home.sessionVariables = {
        OPENCODE_EXPERIMENTAL = true;
      };
    };
}
