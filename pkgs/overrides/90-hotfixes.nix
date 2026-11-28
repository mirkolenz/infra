final: prev:
let
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
}
// (prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {

  # Vicinae pins GCC 15 on linux, but numen uses GCC 16 and requires GLIBCXX_3.4.36.
  # No upstream report, drop it once the pin is gone.
  # https://github.com/vicinaehq/vicinae/blob/main/nix/vicinae.nix
  vicinae = prev.vicinae.override { gcc15Stdenv = final.stdenv; };

  # Sushi overlays every preview with the revealer of its toolbar, which fills the preview
  # when the renderer has no toolbar, such as text, and swallows its scroll and pointer events.
  # The window also grows to at most half of the screen size, now 75%.
  # No upstream report yet.
  sushi = prev.sushi.overrideAttrs (prevAttrs: {
    postPatch = (prevAttrs.postPatch or "") + ''
      substituteInPlace src/widgets/rendererWrapper.js \
        --replace-fail 'hoverManager.setRevealer(null);' \
          'this._revealer.visible = false; hoverManager.setRevealer(null);'
      substituteInPlace src/core/mainWindow.js \
        --replace-fail 'WINDOW_MAX_PERCENT_W = 0.5' 'WINDOW_MAX_PERCENT_W = 0.75' \
        --replace-fail 'WINDOW_MAX_PERCENT_H = 0.5' 'WINDOW_MAX_PERCENT_H = 0.75'
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
