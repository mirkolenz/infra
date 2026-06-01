{ ... }:
{
  services.ollama = {
    enable = false;
    # ollama serve --help
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = toString (64 * 1024);
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KEEP_ALIVE = "-1";
      OLLAMA_KV_CACHE_TYPE = "q4_0";
      OLLAMA_MAX_LOADED_MODELS = "8";
      OLLAMA_NO_CLOUD = "1";
      OLLAMA_NUM_PARALLEL = "1";
    };
  };
}
