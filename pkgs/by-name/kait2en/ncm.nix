# The integration shared by the daemons on the T2's CDC-NCM link: a udev rule
# bringing it up outside NetworkManager, and a sleep unit running their hooks.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/shared
{
  lib,
  stdenvNoCC,
  kait2en,
  coreutils,
  iproute2,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kait2en-ncm";
  version = "0.1.13-unstable-2026-11-07";

  src = kait2en.fetchSource {
    rev = "76bfd1fe4f7c085d16b421a27f2161ca52b82568";
    hash = "sha256-S+uzWHgSj/07UQnQp7ezwlj70apJzhDvwkTGAleV3Oc=";
    root = "t2-services/shared";
    paths = [
      "!t2-services/shared/protocols/"
      # Installed by the Makefile and removed again below.
      "packaging/lifecycle/kait2en-lifecycle.py"
    ];
  };

  dontConfigure = true;
  dontBuild = true;

  makeFlags = [
    "-C"
    finalAttrs.src.root
    "PREFIX=${placeholder "out"}"
    "SYSCONFDIR=${placeholder "out"}/etc"
  ];

  # Upstream's package lifecycle has nothing to migrate here.
  postInstall = ''
    rm -r $out/libexec/t2-services/{lifecycle.py,migration,package-actions}
    # `apple-t2/bridge.nix` declares its NetworkManager settings.
    rm -r $out/etc
    ${kait2en.patchScript {
      path = "$out/libexec/t2-services/t2-ncm-sleep";
      runtimeInputs = [ coreutils ];
    }}
    substituteInPlace $out/lib/udev/rules.d/90-t2-services-ncm.rules \
      --replace-fail /usr/sbin/ip ${lib.getExe' iproute2 "ip"}
    ${kait2en.installLicenses finalAttrs.pname}
  '';

  strictDeps = true;
  __structuredAttrs = true;

  meta = kait2en.commonMeta // {
    description = "Apple T2 CDC-NCM link integration";
  };
})
