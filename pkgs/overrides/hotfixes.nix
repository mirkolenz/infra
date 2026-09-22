final: prev:
{
  # texlive 2025 bundles latexminted 0.6.0, whose argparse subclass rejects the `color` keyword
  # that python 3.14 forwards to `add_parser()`. Fixed upstream in latexminted 0.7.0, which only
  # ships with texlive 2026. https://github.com/NixOS/nixpkgs/issues/542483
  texlive = prev.texlive.override { python3 = final.python313; };

  # nix-update 1.16.0 resolves a package's current ref as `rev or tag`. A src written with
  # nixpkgs' newer `fetchFromGitHub { tag = ...; }` expands that to `refs/tags/v1.2.3`, which
  # never equals the plain `v1.2.3` the version fetcher reports, so every run counts as a change
  # and re-fetches the source plus vendorHash/cargoHash/npmDepsHash even when nothing moved.
  # Fixed upstream by 4f9f5341 (prefer tag over rev) and d45c6cfe (skip unchanged versions that
  # pin neither), both merged after the 1.16.0 release.
  # https://github.com/Mic92/nix-update/commit/4f9f53413
  nix-update = prev.nix-update.overrideAttrs (prevAttrs: {
    postPatch = (prevAttrs.postPatch or "") + ''
      substituteInPlace nix_update/update.py \
        --replace-fail 'old_rev_tag = package.rev or package.tag' \
                       'old_rev_tag = package.tag or package.rev' \
        --replace-fail 'package.new_version.rev is not None and package.new_version.rev != old_rev_tag' \
                       'old_rev_tag is not None and package.new_version.rev is not None and package.new_version.rev != old_rev_tag'
    '';
  });
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
