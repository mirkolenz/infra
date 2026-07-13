final: prev:
{ }
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  inherit (final.stable)
    icloudpd
    ;
})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
})
