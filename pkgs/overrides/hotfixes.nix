final: prev:
{
  inherit (final.stable)
    sbomnix
    ;
}
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  inherit (final.stable)
    icloudpd
    ;
})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
})
