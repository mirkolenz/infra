final: prev:
{ }
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  llama-cpp =
    (prev.llama-cpp.override {
      nodejs_latest = prev.nodejs;
    }).overrideAttrs
      (old: {
        passthru = (old.passthru or { }) // {
          updateScript = null;
        };
      });
})
