{
  lib,
  stdenvNoCC,
  kait2en,
}:
# Upstream bash helpers, installed rather than built, see `patchScript.nix`.
lib.extendMkDerivation {
  constructDrv = stdenvNoCC.mkDerivation;
  excludeDrvArgNames = [
    "script"
    "runtimeInputs"
  ];
  extendDrvArgs =
    finalAttrs:
    {
      script,
      runtimeInputs ? [ ],
      meta ? { },
      ...
    }:
    let
      program = "$out/bin/${finalAttrs.meta.mainProgram}";
    in
    {
      inherit (kait2en.modules) version src;

      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        install -Dm555 ${script} ${program}
        ${kait2en.patchScript {
          path = program;
          inherit runtimeInputs;
        }}
        ${kait2en.installLicenses finalAttrs.pname}

        runHook postInstall
      '';

      strictDeps = true;
      __structuredAttrs = true;

      meta = kait2en.commonMeta // meta;
    };
}
