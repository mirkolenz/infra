# Local LLM inference server (llama.cpp) on macOS.
{
  flake.modules.darwin.default =
    { pkgs, lib, ... }:
    let
      # https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
      modelsPreset = {
        "*" = rec {
          # keep-sorted start
          agent = true;
          cache-ram = 0; # unified memory
          cache-type-k = "q8_0";
          cache-type-v = "q8_0";
          ctx-size = 256 * 1024 * parallel;
          fit = "off";
          flash-attn = "on";
          kv-unified = false;
          load-mode = "mlock";
          n-gpu-layers = "all";
          parallel = 1;
          reasoning-preserve = true;
          sleep-idle-seconds = -1;
          spec-draft-type-k = "q8_0";
          spec-draft-type-v = "q8_0";
          tools = true;
          # keep-sorted end
        };
        "qwen3.8-27b" = {
          # keep-sorted start
          hf-repo = "unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL";
          min-p = 0.0;
          spec-draft-n-max = 3;
          # ngram-mod drafts repeated text for free and has priority, MTP is the fallback
          spec-type = "ngram-mod,draft-mtp";
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
