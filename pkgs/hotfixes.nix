final: prev:
{ }
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  inherit (final.stable)
    llama-cpp
    ;
})
