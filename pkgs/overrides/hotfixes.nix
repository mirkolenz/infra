final: prev:
{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (
      pyFinal: pyPrev:
      let
        # sip 6.16 rejects bindings targeting an ABI major version that the .sip files do not
        # declare via %MinimumABIVersion, a directive PyQt5 5.15.x does not use anywhere
        sip = pyPrev.sip.overridePythonAttrs (prevAttrs: {
          version = "6.15.1";
          src = pyPrev.fetchPypi {
            inherit (prevAttrs) pname;
            version = "6.15.1";
            hash = "sha256-3C5YwXmKdOGzHCjoNzOYIv6PpVKIrjDomG6ygQDrylo=";
          };
        });
      in
      {
        pyqt5 = pyPrev.pyqt5.override {
          inherit sip;
          # pyqt-builder propagates sip into the build environment as well, so both have to agree
          pyqt-builder = pyPrev.pyqt-builder.override { inherit sip; };
        };
      }
    )
  ];
}
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  # test_make_tmpdir creates the shared /tmp/not-too-long, which the darwin sandbox does not
  # isolate, so it is owned by whichever build user ran first and fails for every other one
  nixos-rebuild-ng = prev.nixos-rebuild-ng.overridePythonAttrs (prevAttrs: {
    disabledTests = (prevAttrs.disabledTests or [ ]) ++ [ "test_make_tmpdir" ];
  });
})
