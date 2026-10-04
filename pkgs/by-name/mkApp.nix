{
  stdenvNoCC,
  makeBinaryWrapper,
  lib,
}:
lib.extendMkDerivation {
  constructDrv = stdenvNoCC.mkDerivation;
  excludeDrvArgNames = [ "executable" ];
  extendDrvArgs =
    finalAttrs:
    {
      # custom
      # path of an executable inside the app bundle, exposed as `meta.mainProgram`
      executable ? null,
      # upstream
      nativeBuildInputs ? [ ],
      meta ? { },
      ...
    }:
    {
      installPhase = ''
        runHook preInstall

        mkdir -p "$out/Applications"
        cp -R "${finalAttrs.meta.mainDarwinApp}" "$out/Applications"

        ${lib.optionalString (executable != null) ''
          mkdir -p "$out/bin"
          makeBinaryWrapper "$out/Applications/${finalAttrs.meta.mainDarwinApp}/${executable}" "$out/bin/${finalAttrs.meta.mainProgram}"
        ''}

        runHook postInstall
      '';

      dontConfigure = true;
      dontBuild = true;
      strictDeps = true;
      __structuredAttrs = true;

      nativeBuildInputs = nativeBuildInputs ++ lib.optionals (executable != null) [ makeBinaryWrapper ];

      # without an executable there is no binary, also when an outer builder sets mainProgram
      meta = removeAttrs (
        {
          mainDarwinApp = "${finalAttrs.pname}.app";
          mainProgram = finalAttrs.pname;
          maintainers = with lib.maintainers; [ mirkolenz ];
          platforms = lib.platforms.darwin;
          sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
        }
        // meta
      ) (lib.optional (executable == null) "mainProgram");
    };
}
