final: prev:
{ }
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  # test_make_tmpdir creates the shared /tmp/not-too-long, which the darwin sandbox does not
  # isolate, so it is owned by whichever build user ran first and fails for every other one
  nixos-rebuild-ng = prev.nixos-rebuild-ng.overridePythonAttrs (prevAttrs: {
    disabledTests = (prevAttrs.disabledTests or [ ]) ++ [ "test_make_tmpdir" ];
  });
})
