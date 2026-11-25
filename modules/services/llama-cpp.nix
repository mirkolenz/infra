# Local LLM inference server (llama.cpp) on macOS.
{
  flake.modules.darwin.default = {
    services.llama-cpp = {
      enable = true;
      # https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
      presets = {
        "*" = {
          # keep-sorted start
          agent = true;
          cache-ram = 8 * 1024; # MiB, prompt states kept when switching between sessions
          cache-type-k = "q8_0";
          cache-type-v = "q8_0";
          ctx-size = 256 * 1024; # shared by all slots
          dedup-cache-models = true;
          fit = "off";
          flash-attn = "on";
          kv-unified = true;
          load-mode = "mlock";
          n-gpu-layers = "all";
          parallel = 4;
          reasoning-preserve = true;
          sleep-idle-seconds = -1;
          spec-draft-type-k = "q8_0";
          spec-draft-type-v = "q8_0";
          tools = true;
          # keep-sorted end
        };
        # https://unsloth.ai/docs/models/qwen3.6#recommended-settings
        # the regular GGUF repo lacks the MTP head
        "qwen3.6-35b-a3b" = {
          # keep-sorted start
          hf-repo = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL";
          min-p = 0.0;
          spec-draft-n-max = 2;
          # ngram-mod drafts repeated text for free and has priority, MTP is the fallback
          spec-type = "ngram-mod,draft-mtp";
          temperature = 1.0;
          top-k = 20;
          top-p = 0.95;
          # keep-sorted end
        };
        # Needs llama.cpp 1.1.0, nixpkgs ships 1.0.0.
        # https://unsloth.ai/docs/models/inkling-2-mini#recommended-settings
        # https://github.com/ggml-org/llama.cpp/blob/master/docs/speculative.md#dspark-draft-dspark
        # The 8-bit quant keeps the original NVFP4 experts, so it is lossless at 23 GB.
        # The repo ships the DSpark drafter as a sidecar, fetched for `draft-dspark`.
        # Add it to `programs.agents.providers.llama-cpp` as well, with every effort, the effort `xhigh`, and an output of 65536 of up to 1M.
        # "inkling-2-mini" = {
        #   # keep-sorted start
        #   hf-repo = "unsloth/Inkling-2-Mini-GGUF:UD-Q8_K_XL";
        #   min-p = 0.0;
        #   reasoning-effort = "xhigh"; # the template defaults to high
        #   spec-draft-n-max = 3;
        #   spec-draft-sampling = "probabilistic";
        #   spec-type = "ngram-mod,draft-dspark";
        #   temperature = 1.0;
        #   top-k = 0;
        #   top-p = 1.0;
        #   # keep-sorted end
        # };
      };
      settings = {
        # keep-sorted start
        models-max = 1;
        no-models-autoload = true;
        port = 18000;
        # keep-sorted end
      };
    };
  };
}
