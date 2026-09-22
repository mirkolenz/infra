final: prev:
{
  # texlive 2025 bundles latexminted 0.6.0, whose argparse subclass rejects the `color` keyword
  # that python 3.14 forwards to `add_parser()`. Fixed upstream in latexminted 0.7.0, which only
  # ships with texlive 2026. https://github.com/NixOS/nixpkgs/issues/542483
  texlive = prev.texlive.override { python3 = final.python313; };
}
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

})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {

  # nixpkgs carries a separate vendorHash per platform for scorecard, and the darwin one went
  # stale: the go module proxy no longer reproduces it, so the fixed-output go-modules derivation
  # fails before the build starts. The linux hash still matches, which is why hydra only reports
  # darwin failures. Pin the hash the current dependency set produces until nixpkgs rewrites it.
  scorecard = prev.scorecard.overrideAttrs (
    prevAttrs:
    prev.lib.optionalAttrs (prevAttrs.version == "5.5.0") {
      vendorHash = "sha256-0KKKZheDNRPLBWtwXgXXG+ixpESO+Gq1FsW83PldiVo=";
    }
  );

})
