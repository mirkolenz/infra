final: prev:
let
  # Under __structuredAttrs, makeWrapper receives each `makeWrapperArgs` entry as one argument,
  # so a single "--prefix PATH : ..." string has to be split into its words.
  splitWrapperArgs =
    pkg:
    pkg.overridePythonAttrs (prevAttrs: {
      makeWrapperArgs = prev.lib.concatMap (prev.lib.splitString " ") prevAttrs.makeWrapperArgs;
    });
in
{
  # mago keeps a path into rustc, an unused `LC_RPATH` on darwin, which pulls its gigabyte into
  # every closure with mago, such as those of the formatters. No upstream fix yet.
  mago = prev.mago.overrideAttrs (prevAttrs: {
    nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ final.removeReferencesTo ];
    postFixup = (prevAttrs.postFixup or "") + ''
      remove-references-to -t ${final.rustc.unwrapped} $out/bin/mago
    '';
    disallowedReferences = [ final.rustc.unwrapped ];
  });

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

  # direnv's buildPhase and installPhase never run their hooks, so the postInstall that drops
  # share/fish is skipped. The shipped vendor_conf.d/direnv.fish then hooks every fish,
  # including each `fish -c`, where home-manager only hooks interactive shells.
  # https://github.com/NixOS/nixpkgs/pull/564930
  direnv = prev.direnv.overrideAttrs {
    buildPhase = ''
      runHook preBuild
      make BASH_PATH=$BASH_PATH
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      make install PREFIX=$out
      runHook postInstall
    '';
  };

  # https://github.com/NixOS/nixpkgs/pull/575801
  sbomnix = splitWrapperArgs prev.sbomnix;

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_: pyprev: {
      # typepy 2.0.0 landed before the consumers dropped their `typepy<2` pin.
      # https://github.com/NixOS/nixpkgs/pull/573108
      sqliteschema = pyprev.sqliteschema.overridePythonAttrs { pythonRelaxDeps = [ "typepy" ]; };
      simplesqlite = pyprev.simplesqlite.overridePythonAttrs { pythonRelaxDeps = [ "typepy" ]; };

      # sphinxHook only reads the first entry of an array `sphinxBuilders` under __structuredAttrs,
      # so the man output is never built. A single space-separated entry works around it.
      # https://github.com/NixOS/nixpkgs/pull/573479
      reuse = pyprev.reuse.overridePythonAttrs { sphinxBuilders = [ "html man" ]; };

      # `is_archive` rejects the squashfs fixtures although libmagic still identifies them.
      # No upstream report yet, the hydra job shows when it passes again.
      # https://hydra.nixos.org/job/nixpkgs/unstable/python314Packages.typecode.aarch64-linux
      typecode = pyprev.typecode.overridePythonAttrs (prevAttrs: {
        disabledTests = prevAttrs.disabledTests ++ [
          "test_archive_squashfs_lzo"
          "test_archive_squashfs_xz"
        ];
      });

      # patchelf 0.19.2 aborts on the large prebuilt binary with `splitIndex == -1`
      # https://github.com/NixOS/patchelf/pull/672
      semgrep = pyprev.semgrep.override (prevArgs: {
        semgrep-core = prevArgs.semgrep-core.override { patchelf = final.buildPackages.patchelf-fixed; };
      });
    })
  ];
}
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {

  # Nix 2.35 opens the root directory with O_RDONLY, which Landlock denies within nono,
  # since it cannot grant listing `/` without everything below it.
  # Only the patched nix-util is built and grafted into Determinate's build,
  # which relies on the patch leaving its ABI unchanged.
  # Drop once the locked Nix opens the root with O_PATH.
  # https://github.com/NixOS/nix/issues/16164
  determinate-nix =
    let
      inherit (prev) lib;
      nix = prev.determinate-nix;
      packages = final.inputs.determinate.inputs.nix.packages.${prev.stdenv.hostPlatform.system};
      nixUtil = nix.libs.nix-util;

      # The components linking nix-util bottom-up, each one rewritten with the replacements
      # of those before it, without import-from-derivation unlike `replaceDependencies`.
      replacements =
        lib.foldl'
          (
            acc: drv:
            acc
            ++ [
              {
                oldDependency = drv;
                newDependency = final.replaceDirectDependencies {
                  inherit drv;
                  replacements = acc;
                };
              }
            ]
          )
          [
            {
              oldDependency = nixUtil;
              newDependency = nixUtil.overrideAttrs (prevAttrs: {
                patches = prevAttrs.patches or [ ] ++ [ ./nix-root-o-path.patch ];
                # relative to the repository, while the build runs in src/libutil
                patchFlags = [ "-p3" ];
              });
            }
          ]
          (
            lib.attrVals [
              "nix-store"
              "nix-fetchers"
              "nix-main"
              "nix-expr"
              "nix-flake"
              "nix-cmd"
            ] nix.libs
            ++ [
              packages.nix-cli
              packages.nix-nswrapper
            ]
          );
    in
    (final.replaceDirectDependencies {
      drv = nix;
      inherit replacements;
    }).overrideAttrs
      {
        # A component missing above would keep the unpatched nix-util, which fails the build.
        disallowedRequisites = [ nixUtil ];
        # the NixOS module reads `pname`, and the graft has the `out` output only
        passthru = {
          inherit (nix) pname version;
        };
        meta = removeAttrs nix.meta [ "outputsToInstall" ];
      };

  # Vicinae pins GCC 15 on linux, but numen uses GCC 16 and requires GLIBCXX_3.4.36.
  # No upstream report, drop it once the pin is gone.
  # https://github.com/vicinaehq/vicinae/blob/main/nix/vicinae.nix
  vicinae = prev.vicinae.override { gcc15Stdenv = final.stdenv; };

  # kingfisher links mimalloc 3.3.2 (libmimalloc-sys 0.1.49) with the `override` feature, so it
  # replaces libc's malloc and free. glibc 2.44 calls free(NULL) while libstdc++ initializes,
  # before mimalloc has set up its page map, so the binary segfaults before main() and prints
  # nothing. Fixed in mimalloc 3.4.4. Dropping the feature keeps mimalloc as the rust allocator.
  # https://github.com/microsoft/mimalloc/issues/1341
  kingfisher = prev.kingfisher.overrideAttrs (prevAttrs: {
    postPatch = (prevAttrs.postPatch or "") + ''
      substituteInPlace Cargo.toml \
        --replace-fail 'mimalloc = { version = "0.1.52", features = ["override"] }' \
                       'mimalloc = "0.1.52"'
    '';
  });

})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {

  # Replace the SVG driver's Windows-only header with POSIX headers, as Homebrew does.
  # https://github.com/Homebrew/homebrew-core/pull/261141
  pstoedit = prev.pstoedit.overrideAttrs (prevAttrs: {
    postPatch = (prevAttrs.postPatch or "") + ''
      substituteInPlace src/drvsvg.cpp \
        --replace-fail '#include <io.h>' $'#include <unistd.h>\n#include <fcntl.h>'
    '';
  });

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
