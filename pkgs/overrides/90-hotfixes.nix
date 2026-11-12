final: prev:
let
  # pluggy 1.7 only accepts functions as hookspecs, so registering the class-based ones of
  # plugincode and scancode fails. Both only load entry points through pluggy and never call a hook,
  # so the registration becomes a no-op expression.
  # https://github.com/aboutcode-org/plugincode/pull/15
  dropHookspecs =
    drv: files:
    drv.overridePythonAttrs (prevAttrs: {
      postPatch = (prevAttrs.postPatch or "") + ''
        substituteInPlace ${prev.lib.escapeShellArgs files} \
          --replace-fail 'self.manager.add_hookspecs(' '('
      '';
    });

  # CI skips the overrides whose builds exceed the time or memory of its runners,
  # so the hosts build them until they can go.
  inherit (prev.lib) dontDistribute;
in
{
  # mago links with an rpath into the rustlib of rustc, which pulls its gigabyte into every
  # closure with mago, such as those of the formatters. No upstream report yet.
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

  # nixpkgs pins nilaway from 2025-03, whose vendored golang.org/x/tools panics
  # with `unexpected expr: *ast.KeyValueExpr` while building the SSA of Go 1.27 code on linux.
  # The integration tests of the root package exceed the time and memory of the CI runners.
  nilaway = prev.nilaway.overrideAttrs {
    doCheck = false;
    version = "0-unstable-2026-09-18";
    src = final.fetchFromGitHub {
      owner = "uber-go";
      repo = "nilaway";
      rev = "acb8859b9031bb9496be97e027df5573f9fb5340";
      hash = "sha256-GvDZ5tlvOrTI93tYcIcLd45ZHdqwFopVtoBffD/kbuM=";
    };
    vendorHash = "sha256-qVmvDneq6V/q5UHZ/Cjjqd5/XPPNfvVGoxwg9nz4/Ds=";
  };

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

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (
      _: pyprev:
      {
        plugincode = dropHookspecs pyprev.plugincode [
          "src/plugincode/__init__.py"
          "src/plugincode/location_provider.py"
        ];
        scancode-toolkit = dropHookspecs pyprev.scancode-toolkit [
          "src/licensedcode/additional_license_location_provider.py"
        ];

        # libarchive 3.8 extracts ar members under other names than the fixtures expect,
        # and no longer rejects members with relative paths. No upstream report yet.
        extractcode = pyprev.extractcode.overridePythonAttrs (prevAttrs: {
          disabledTests = prevAttrs.disabledTests ++ [
            "test_extract_ar_with_permissions"
            "test_extract_ar_with_relative_path"
            "test_extract_directory_of_windows_ar_archives"
          ];
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

  # Sushi overlays every preview with the revealer of its toolbar, which fills the preview
  # when the renderer has no toolbar, such as text, and swallows its scroll and pointer events.
  # The window also grows to at most half of the screen height, now 85% like Quick Look.
  # No upstream report yet.
  sushi = prev.sushi.overrideAttrs (prevAttrs: {
    postPatch = (prevAttrs.postPatch or "") + ''
      substituteInPlace src/widgets/rendererWrapper.js \
        --replace-fail 'hoverManager.setRevealer(null);' \
          'this._revealer.visible = false; hoverManager.setRevealer(null);'
      substituteInPlace src/core/mainWindow.js \
        --replace-fail 'WINDOW_MAX_PERCENT_H = 0.5' 'WINDOW_MAX_PERCENT_H = 0.85'
    '';
  });

  # The window of tuxpaint identifies itself as TuxPaint.TuxPaint, which its desktop entry does
  # not declare, so GNOME shows the running app apart from its launcher. No upstream report yet.
  tuxpaint = dontDistribute (
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
  # The vendored modernc.org/libc also panics in the darwin sandbox when it reads /etc/protocols
  # and /etc/services, so the tests get the iana-etc copies through libredirect.
  # Its setup hook would also apply to `go build` and break it, so it is only injected for tests.
  scorecard = prev.scorecard.overrideAttrs (
    prevAttrs:
    {
      preCheck = prevAttrs.preCheck + ''
        export DYLD_INSERT_LIBRARIES=${final.libredirect}/lib/libredirect.dylib
        export NIX_REDIRECTS=/etc/protocols=${final.iana-etc}/etc/protocols:/etc/services=${final.iana-etc}/etc/services
      '';
    }
    // prev.lib.optionalAttrs (prevAttrs.version == "5.5.0") {
      vendorHash = "sha256-0KKKZheDNRPLBWtwXgXXG+ixpESO+Gq1FsW83PldiVo=";
    }
  );

})
