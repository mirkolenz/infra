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
  version = "0.1.16-unstable-2026-11-21";

  src = kait2en.fetchSource {
    rev = "fd46d003c2599fb28bbde6a90f99816d73b04e61";
    hash = "sha256-FVPEre2WC1gL2BUE9ew/pFMHIJdn+go2vM85/oe3Knc=";
    root = "modules/apple-t2-alsa-ucm-conf";
  };

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
