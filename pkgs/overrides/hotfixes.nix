final: prev:
{ }
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  llama-cpp = final.lib'.disableUpdateScript (
    prev.llama-cpp.override {
      nodejs_latest = prev.nodejs;
    }
  );
  podman = prev.lib.addMetaAttrs {
    platforms = prev.lib.platforms.unix;
  } prev.podman;
})
