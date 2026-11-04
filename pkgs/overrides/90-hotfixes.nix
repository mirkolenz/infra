final: prev:
{
  # mago links with an rpath into the rustlib of rustc, which pulls its gigabyte into every
  # closure with mago, such as those of the formatters. No upstream report yet.
  # Patching the cached binary avoids compiling mago, which outlasts the CI timeouts.
  # `runCommand` over `runCommandLocal`, since substituting the result spares fetching rustc.
  mago =
    final.runCommand prev.mago.name
      {
        inherit (prev.mago) pname version meta;
        nativeBuildInputs = [ final.removeReferencesTo ];
        disallowedReferences = [ final.rustc.unwrapped ];
      }
      ''
        cp -R ${prev.mago} $out
        chmod -R u+w $out
        remove-references-to -t ${final.rustc.unwrapped} $out/bin/mago
      '';

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

  # Release builds give redaction 250 ms, so a loaded builder records captured messages as
  # "took too long to redact", and the ai-session e2e tests that read them back fail at random.
  # nixpkgs#578792 skips them one by one, which keeps missing some, and the tests compile the
  # workspace a second time. Drop once hydra builds atuin on every system again.
  # https://hydra.nixos.org/build/351752391
  atuin = prev.atuin.overrideAttrs { doCheck = false; };

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

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (
      pyfinal: pyprev:
      {
        # patchelf 0.19.2 aborts on the large prebuilt binary with `splitIndex == -1`
        # https://github.com/NixOS/patchelf/pull/672
        # semgrep imports `mcp.server.fastmcp`, which mcp 2 removed.
        semgrep = pyprev.semgrep.override (prevArgs: {
          mcp = pyfinal.mcp_1;
          semgrep-core = prevArgs.semgrep-core.override { patchelf = final.buildPackages.patchelf-fixed; };
        });
      }
      // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        # Importing libvirt loads system frameworks down to Apple's LibreSSL, which aborts once the
        # darwin sandbox denies it /private/etc/ssl/openssl.cnf, a path it hardcodes, so it builds
        # outside the sandbox. No upstream report yet.
        libvirt-python = pyprev.libvirt-python.overridePythonAttrs { __noChroot = true; };
      }
    )
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

  # The window of tuxpaint identifies itself as TuxPaint.TuxPaint, which its desktop entry does
  # not declare, so GNOME shows the running app apart from its launcher. No upstream report yet.
  tuxpaint = prev.lib.dontDistribute (
    prev.tuxpaint.overrideAttrs (prevAttrs: {
      nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ final.desktop-file-utils ];
      postInstall = (prevAttrs.postInstall or "") + ''
        desktop-file-edit --set-key=StartupWMClass --set-value=TuxPaint.TuxPaint \
          $out/share/applications/tuxpaint.desktop
      '';
    })
  );

})
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {

  # libvirt links with -flat_namespace for its test mocks, so once a process has loaded Apple's
  # libxml2 2.9 through system frameworks, its libxml2 calls bind there instead of to libxml2 2.15.
  # The void xmlSchemaInitTypes of 2.9 then returns garbage, failing XML validation at random.
  # Two-level binding fixes that, but breaks the test mocks, which need flat lookups.
  # No upstream report yet.
  libvirt = prev.libvirt.overrideAttrs (prevAttrs: {
    postPatch = prevAttrs.postPatch + ''
      substituteInPlace meson.build --replace-fail "'-Wl,-flat_namespace'" "[]"
    '';
    doCheck = false;
  });

  # xcp 0.24.9 renamed its tests to `test_case_1_test_with_parallel_file_driver`,
  # so the darwin skips of nixpkgs no longer match. Skipping the modules survives such renames.
  # No upstream report yet.
  xcp = prev.xcp.overrideAttrs {
    checkFlags = map (module: "--skip=${module}::") [
      "test_socket_file"
      "test_sockets_dir"
      "dir_copy_deref_symlinks"
    ];
  };

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
