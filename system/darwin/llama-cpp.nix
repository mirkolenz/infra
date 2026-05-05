{ ... }:
{
  services.llama-cpp = {
    enable = true;
    port = 18000;
    extraFlags = [
      "--no-models-autoload"
      "--models-max"
      "10"
    ];
    # https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
    modelsPreset = {
      "*" = rec {
        # keep-sorted start
        cache-ram = 0; # unified memory
        cache-type-k = "q8_0";
        cache-type-v = "q8_0";
        ctx-size = 64 * 1024 * parallel;
        flash-attn = "on";
        mlock = true;
        mmap = false;
        n-gpu-layers = "all";
        parallel = 2;
        sleep-idle-seconds = -1;
        # keep-sorted end
      };
      # https://unsloth.ai/docs/models/qwen3.6
      "qwen3.6-35b-a3b" = {
        # keep-sorted start
        hf-repo = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";
        min-p = 0.0;
        presence-penalty = 1.0;
        reasoning = "on";
        repeat-penalty = 1.0;
        temperature = 1.0;
        top-k = 20;
        top-p = 0.95;
        # keep-sorted end
      };
      # https://unsloth.ai/docs/models/qwen3.5
      "qwen3.5-0.8b" = {
        # keep-sorted start
        hf-repo = "unsloth/Qwen3.5-0.8B-GGUF:UD-Q4_K_XL";
        min-p = 0.0;
        presence-penalty = 1.0;
        reasoning = "off";
        repeat-penalty = 1.0;
        temperature = 1.0;
        top-k = 20;
        top-p = 0.95;
        # keep-sorted end
      };
    };
  };
}
