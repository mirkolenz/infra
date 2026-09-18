# PipeWire filter graphs reproducing what macOS applies to the internal
# speakers. A udev rule renames the ALSA card after the DMI model, which is how
# WirePlumber picks the matching profile.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/dsp
{
  lib,
  stdenvNoCC,
  kait2en,
  python3,
  coreutils,
  bankstown-lv2,
  lsp-plugins,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kait2en-dsp";
  inherit (kait2en.modules) version src;

  sourceRoot = "${finalAttrs.src.name}/dsp";

  nativeBuildInputs = [ python3 ];

  # The generated udev rule shells out to read the model out of DMI.
  postPatch = ''
    substituteInPlace tools/build.py \
      --replace-fail /usr/bin/cat ${lib.getExe' coreutils "cat"}
  '';

  # `PREFIX` also ends up inside the graphs, which use absolute paths.
  makeFlags = [ "PREFIX=${placeholder "out"}" ];

  # An RPM and Debian migration helper with nothing to convert here. The license
  # notices come out of the upstream Makefile instead of `installLicenses`.
  postInstall = ''
    rm -r $out/libexec
  '';

  passthru.requiredLv2Packages = [
    bankstown-lv2
    lsp-plugins
  ];

  strictDeps = true;
  __structuredAttrs = true;

  meta = kait2en.commonMeta // {
    description = "Speaker DSP profiles for the Apple T2 audio driver";
  };
})
