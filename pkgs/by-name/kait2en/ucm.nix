# The use case profiles of snd-apple-t2, which exposes a plain ALSA device.
# `apple-t2/audio.nix` merges them into the stock UCM tree, like
# `alsa-ucm-conf-asahi`.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/modules/apple-t2-alsa-ucm-conf
{
  stdenvNoCC,
  kait2en,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kait2en-ucm";
  version = "0.1.14-unstable-2026-11-15";

  src = kait2en.fetchSource {
    rev = "260a559597a7bd3b168a9a251a2248d97aadd957";
    hash = "sha256-FVPEre2WC1gL2BUE9ew/pFMHIJdn+go2vM85/oe3Knc=";
    root = "modules/apple-t2-alsa-ucm-conf";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/alsa
    cp -r ${finalAttrs.src.root}/ucm2 $out/share/alsa/

    ${kait2en.installLicenses finalAttrs.pname}

    runHook postInstall
  '';

  strictDeps = true;
  __structuredAttrs = true;

  # Configuration rather than a kernel module, despite sitting under `modules/`.
  meta = kait2en.commonMeta // {
    description = "Apple T2 audio profiles for ALSA UCM";
  };
})
