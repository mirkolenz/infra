# PipeWire filter graphs reproducing what macOS applies to the internal
# speakers. A udev rule renames the ALSA card after the DMI model, which the
# graphs of that model target. `forModel` selects them the way upstream's
# installer does.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/dsp
{
  lib,
  stdenvNoCC,
  runCommandLocal,
  jq,
  kait2en,
  udevCheckHook,
  python3,
  coreutils,
  bankstown-lv2,
  lsp-plugins,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kait2en-dsp";
  version = "0.1.16-unstable-2026-11-25";

  src = kait2en.fetchSource {
    rev = "ba0f3f6ebd510f742f6165b13d2fce13ddda6977";
    hash = "sha256-pwQkd4fRjuY/OH5ec4a0VAM/IT40l+pq2o9zGwIOQGA=";
    root = "dsp";
    # Installed by the Makefile and removed again below.
    paths = [ "packaging/lifecycle/kait2en-lifecycle.py" ];
  };

  sourceRoot = "${finalAttrs.src.name}/${finalAttrs.src.root}";

  nativeBuildInputs = [ python3 ];

  # The generated udev rule shells out to read the model out of DMI.
  postPatch = ''
    substituteInPlace tools/build.py \
      --replace-fail /usr/bin/cat ${lib.getExe' coreutils "cat"}
  '';

  # `PREFIX` also ends up inside the graphs, which use absolute paths.
  makeFlags = [ "PREFIX=${placeholder "out"}" ];

  # An RPM and Debian migration helper with nothing to convert here.
  postInstall = ''
    rm -r $out/libexec $out/share/licenses/t2-dsp
    ${kait2en.installLicenses finalAttrs}
  '';

  # A PipeWire config package loading the graphs of one DMI product name.
  passthru.forModel =
    model:
    runCommandLocal "kait2en-dsp-pipewire"
      {
        nativeBuildInputs = [ jq ];
        passthru.requiredLv2Packages = [
          bankstown-lv2
          lsp-plugins
        ];
      }
      ''
        profile=$(jq -er --arg model ${lib.escapeShellArg model} '.[$model]' \
          ${finalAttrs.finalPackage}/share/t2-dsp/models.json)
        install -Dm444 ${finalAttrs.finalPackage}/share/t2-dsp/pipewire/$profile.conf \
          $out/share/pipewire/pipewire.conf.d/51-t2-dsp.conf
      '';

  nativeInstallCheckInputs = [ udevCheckHook ];
  doInstallCheck = true;

  strictDeps = true;
  __structuredAttrs = true;

  meta = kait2en.commonMeta // {
    description = "Speaker DSP profiles for the Apple T2 audio driver";
  };
})
