# Local LLM inference server (llama.cpp) on macOS.
{
  flake.modules.darwin.default =
    { pkgs, lib, ... }:
    let
      # https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
      modelsPreset = {
        "*" = rec {
          # keep-sorted start
          cache-ram = 0; # unified memory
          cache-type-k = "q8_0";
          cache-type-v = "q8_0";
          ctx-size = 256 * 1024 * parallel;
          flash-attn = "on";
          kv-unified = false;
          mlock = true;
          mmap = false;
          n-gpu-layers = "all";
          parallel = 1;
          reasoning = "on";
          sleep-idle-seconds = -1;
          # keep-sorted end
        };
        # https://unsloth.ai/docs/models/gemma-4/qat
        "gemma4-26b-a4b" = {
          # keep-sorted start
          hf-repo = "unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL";
          temperature = 1.0;
          top-k = 20;
          top-p = 0.95;
          # keep-sorted end
        };
        "gemma4-31b" = {
          # keep-sorted start
          hf-repo = "unsloth/gemma-4-31B-it-qat-GGUF:UD-Q4_K_XL";
          temperature = 1.0;
          top-k = 20;
          top-p = 0.95;
          # keep-sorted end
        };
        # https://unsloth.ai/docs/models/qwen3.6
        "qwen3.6-35b-a3b" = {
          # keep-sorted start
          hf-repo = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL";
          min-p = 0.00;
          spec-draft-n-max = 4;
          spec-type = "draft-mtp";
          temperature = 1.0;
          top-k = 20;
          top-p = 0.95;
          # keep-sorted end
        };
        "qwen3.6-27b" = {
          # keep-sorted start
          hf-repo = "unsloth/Qwen3.6-27B-MTP-GGUF:UD-Q4_K_XL";
          min-p = 0.00;
          spec-draft-n-max = 4;
          spec-type = "draft-mtp";
          temperature = 1.0;
          top-k = 20;
          top-p = 0.95;
          # keep-sorted end
        };
      };
    in
    {
      services.llama-cpp = {
        enable = true;
        settings = {
          # keep-sorted start
          models-max = 1;
          models-preset = pkgs.writeText "llama-models.ini" (lib.generators.toINI { } modelsPreset);
          no-models-autoload = true;
          port = 18000;
          # keep-sorted end
        };
      };
    };
}
