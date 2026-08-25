{
  lib,
  stdenv,
  makeBinaryWrapper,
  prev,
}:
(prev.virt-manager.override {
  # todo: only flaky upstream, so drop this on the next nixpkgs bump that builds
  # two libvirt-python tests fail against the test:/// driver on darwin
  # https://hydra.nixos.org/job/nixpkgs/unstable/python314Packages.libvirt-python.aarch64-darwin
  python3 = prev.python3.override {
    packageOverrides = _: pyPrev: {
      libvirt-python = pyPrev.libvirt-python.overridePythonAttrs (oldAttrs: {
        disabledTests = (oldAttrs.disabledTests or [ ]) ++ [
          "testCheckpointCreate"
          "testDomainIDReturnsValidValue"
        ];
      });
    };
  };
}).overrideAttrs
  (oldAttrs: {
    nativeBuildInputs =
      (oldAttrs.nativeBuildInputs or [ ])
      ++ (lib.optional stdenv.hostPlatform.isDarwin makeBinaryWrapper);
    postInstall =
      (oldAttrs.postInstall or "")
      + (lib.optionalString stdenv.hostPlatform.isDarwin ''
        wrapProgram $out/bin/virt-manager \
          --set GSETTINGS_BACKEND keyfile
      '');
    meta = oldAttrs.meta // {
      hydraPlatforms = lib.platforms.darwin;
    };
  })
