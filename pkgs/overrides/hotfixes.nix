final: prev:
{ }
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {

  # tests/chip.c's setup_bad_chip() hands setup_chip() a pointer to a copy of chip_bad living in
  # its own frame, so flashctx->chip dangles as soon as the helper returns; every other test in
  # the file keeps that copy in the test function instead. On aarch64 the frame is reused before
  # flashrom_image_write() reads chip->total_size, so the size check rejects the buffer and
  # returns 4 instead of the expected ERROR_FLASHROM_PREPARE_FLASH_ACCESS. Give the copy static
  # storage; the assignment stays separate because chip_bad is not a constant initializer.
  # https://github.com/NixOS/nixpkgs/issues/558302
  flashrom = prev.flashrom.overrideAttrs (prevAttrs: {
    postPatch = (prevAttrs.postPatch or "") + ''
      substituteInPlace tests/chip.c \
        --replace-fail 'struct flashchip mock_chip = chip_bad;' \
                       'static struct flashchip mock_chip; mock_chip = chip_bad;'
    '';
  });

  # src/test/file_caps_test.c interposes fgetxattr()/fsetxattr() to mock the security.capability
  # xattr. With a shared libc the test definitions simply win over the libc ones, but linking the
  # test statically pulls musl's xattr.lo out of libc.a (cap-ng.c needs fremovexattr from it) and
  # the linker then sees two definitions of each. Skip the test suite for static builds.
  # https://github.com/stevegrubb/libcap-ng/issues/85
  # https://github.com/NixOS/nixpkgs/pull/562812
  libcap_ng = prev.libcap_ng.overrideAttrs {
    doCheck = !prev.stdenv.hostPlatform.isStatic;
  };

})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {

  # libvirt.dylib is linked with -Wl,-flat_namespace, so its libxml2 imports bind to the system
  # /usr/lib/libxml2.2.dylib that every CPython process maps. There xmlSchemaInitTypes() returns
  # void instead of int, so libvirt reads an uninitialized register and fails schema validation
  # at random. A failure also leaks the shared test:///default state into
  # testDomainIDReturnsValidValue.
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_: pyprev: {
      libvirt-python = pyprev.libvirt-python.overridePythonAttrs (prevAttrs: {
        disabledTests = (prevAttrs.disabledTests or [ ]) ++ [ "testCheckpointCreate" ];
      });
    })
  ];

})
