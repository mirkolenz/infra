{
  stdenvNoCC,
  fetchFromGitHub,
  lib,
  nix-update-script,
  php,
  writeShellApplication,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bibtexbrowser";
  version = "latest";

  src = fetchFromGitHub {
    owner = "monperrus";
    repo = "bibtexbrowser";
    rev = "fbbf95f8a4085d81157ae0df58506b92e4a40b58";
    hash = "sha256-CUnVkuoFLZkYM8fcHTemN/a66LycAH6LOWqNSZXgIeI=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    cp -r $src $out

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script { };
    bibtex2cff = writeShellApplication {
      name = "bibtex2cff";
      text = ''
        exec ${lib.getExe php} ${finalAttrs.finalPackage}/bibtex-to-cff.php "$@"
      '';
      meta = finalAttrs.meta // {
        inherit (php.meta) platforms;
      };
    };
  };

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "Beautiful publication lists with bibtex and PHP";
    homepage = "https://www.monperrus.net/martin/bibtexbrowser/";
    maintainers = with lib.maintainers; [ mirkolenz ];
    platforms = lib.platforms.all;
  };
})
