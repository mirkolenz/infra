{
  lib,
  stdenvNoCC,
  kait2en,
  makeWrapper,
}:
# Upstream bash helpers, installed rather than built: they need a shebang
# rewrite and a PATH that a sleep transition does not provide.
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

      nativeBuildInputs = [ makeWrapper ];

      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        ${kait2en.installScript {
          src = script;
          dest = program;
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
