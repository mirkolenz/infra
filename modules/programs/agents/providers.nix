{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      ...
    }@args:
    let
      llamaCpp = args.osConfig.services.llama-cpp or { enable = false; };
      pythiaTunnel = lib.head config.programs.ssh.settings.pythia-llm.data.LocalForward;
    in
    {
      # the vLLM of pythia, reached through the `pythia-llm` ssh tunnel
      programs.agents.providers.pythia = lib.mkIf config.programs.ssh.enable {
        label = "Pythia";
        url = "http://127.0.0.1:${toString pythiaTunnel.bind.port}";
        # https://unsloth.ai/docs/models/qwen3.8#thinking--preserve-thinking
        models."qwen3.8-27b" = {
          label = "Qwen 3.8";
          # the native context, which vLLM serves without `max-model-len`
          context = 262144;
          output = 32768;
          # https://recipes.vllm.ai/Qwen/Qwen3.8-27B
          efforts = [
            "low"
            "medium"
            "xhigh"
          ];
          effort = "xhigh";
        };
      };

      # the offline fallback, one model per preset of `services.llama-cpp`
      programs.agents.providers.llama-cpp = lib.mkIf llamaCpp.enable {
        label = "llama.cpp";
        url = "http://${llamaCpp.settings.host}:${toString llamaCpp.settings.port}";
        models."qwen3.6-35b-a3b" = {
          label = "Qwen 3.6 MoE";
          context = llamaCpp.presets."*".ctx-size;
          output = 32768;
        };
      };
    };
}
