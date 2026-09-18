# The t2bce driver exposes a plain ALSA device, so its use case profiles have to
# be merged into the stock UCM tree. Shaped like `alsa-ucm-conf-asahi`.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/modules/t2bce_audio-alsa-ucm-conf
{
  lib,
  stdenvNoCC,
  kait2en,
  symlinkJoin,
  alsa-ucm-conf,
}:
let
  # Only the join is published, so it carries the stock tree's license too.
  meta = kait2en.commonMeta // {
    description = "ALSA UCM configuration extended with the Apple T2 audio profiles";
    license = lib.toList alsa-ucm-conf.meta.license ++ [ lib.licenses.gpl3Plus ];
  };

  profiles = stdenvNoCC.mkDerivation {
    pname = "kait2en-ucm";
    inherit (kait2en.modules) version src;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/alsa
      cp -r modules/t2bce_audio-alsa-ucm-conf/ucm2 $out/share/alsa/

      ${kait2en.installLicenses "kait2en-ucm"}

      runHook postInstall
    '';

    strictDeps = true;
    __structuredAttrs = true;

    # Configuration rather than a kernel module, despite sitting under `modules/`.
    meta = kait2en.commonMeta // {
      description = "Apple T2 audio profiles for ALSA UCM";
    };
  };
in
# KaiT2en only adds directories of its own, so the two trees merge cleanly.
symlinkJoin {
  inherit (profiles) pname version;
  inherit meta;
  paths = [
    alsa-ucm-conf
    profiles
  ];
}
