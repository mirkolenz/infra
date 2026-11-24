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
  version = "0.1.16-unstable-2026-11-23";

  src = kait2en.fetchSource {
    rev = "6915384500c59c7ac4842977a40b4269f122bdbc";
    hash = "sha256-Dcxy+WPt4ZKg73YvSIC7n678ejrSuNce7FumdHjuZM0=";
    root = "modules/apple-t2-alsa-ucm-conf";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/alsa
    cp -r ${finalAttrs.src.root}/ucm2 $out/share/alsa/

    ${kait2en.installLicenses finalAttrs}

    runHook postInstall
  '';

  strictDeps = true;
  __structuredAttrs = true;

  # Configuration rather than a kernel module, despite sitting under `modules/`.
  meta = kait2en.commonMeta // {
    description = "Apple T2 audio profiles for ALSA UCM";
  };
})
