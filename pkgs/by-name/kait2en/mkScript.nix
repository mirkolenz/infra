{
  lib,
  stdenvNoCC,
  kait2en,
  makeWrapper,
  runtimeShell,
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

        install -Dm555 ${script} ${program}
        substituteInPlace ${program} \
          --replace-fail '#!/usr/bin/env bash' '#!${runtimeShell}'
        wrapProgram ${program} --prefix PATH : ${lib.makeBinPath runtimeInputs}

        ${kait2en.installLicenses finalAttrs.pname}

        runHook postInstall
      '';

      strictDeps = true;
      __structuredAttrs = true;

      meta = {
        homepage = "https://github.com/kaiT2en/KaiT2en-Fedora";
        license = lib.licenses.gpl3Plus;
        maintainers = with lib.maintainers; [ mirkolenz ];
        platforms = lib.platforms.linux;
        # Only used on a T2 Mac, and a bump rebuilds the whole tree.
        hydraPlatforms = [ ];
      }
      // meta;
    };
}
