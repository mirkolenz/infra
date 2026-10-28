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
  inherit (kait2en.modules) version src;

  dontConfigure = true;
  dontBuild = true;

  makeFlags = [
    "-C"
    "t2-services/shared"
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
