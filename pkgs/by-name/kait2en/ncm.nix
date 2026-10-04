# The integration shared by the daemons on the T2's CDC-NCM link: the
# NetworkManager profile for it, and a sleep unit running their hooks.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/shared
{
  stdenvNoCC,
  kait2en,
  coreutils,
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
    ${kait2en.patchScript {
      path = "$out/libexec/t2-services/t2-ncm-sleep";
      runtimeInputs = [ coreutils ];
    }}
    ${kait2en.installLicenses finalAttrs.pname}
  '';

  strictDeps = true;
  __structuredAttrs = true;

  meta = kait2en.commonMeta // {
    description = "Apple T2 CDC-NCM link integration";
  };
})
