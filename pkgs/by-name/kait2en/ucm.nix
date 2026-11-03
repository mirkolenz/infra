# The use case profiles of the t2bce driver, which exposes a plain ALSA device.
# `apple-t2/audio.nix` merges them into the stock UCM tree, like
# `alsa-ucm-conf-asahi`.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/modules/t2bce_audio-alsa-ucm-conf
{
  stdenvNoCC,
  kait2en,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kait2en-ucm";
  version = "0.1.12-unstable-2026-11-02";

  src = kait2en.fetchSource {
    rev = "3206d9e4ea6cb49caba20f374954220555577fcc";
    hash = "sha256-wk+mDWY96GBZMiP0QUDS5xNx5366GQ/2CfcBF49hngY=";
    root = "modules/t2bce_audio-alsa-ucm-conf";
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
