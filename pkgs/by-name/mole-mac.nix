{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeBinaryWrapper,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "mole";
  version = "1.56.0";

  src = fetchFromGitHub {
    owner = "tw93";
    repo = "Mole";
    tag = "V${finalAttrs.version}";
    hash = "sha256-cgniSoJxSWLhurQaT2JH2vUmHEOw4/X0mhF+M3ve7iM=";
  };

  nativeBuildInputs = [ makeBinaryWrapper ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec

    cp -r bin lib $out/libexec/
    cp mole $out/libexec/
    # cp $finalAttrs.goHelpers/bin/* $out/libexec/bin/

    makeBinaryWrapper $out/libexec/mole $out/bin/mole
    makeBinaryWrapper $out/libexec/mole $out/bin/mo

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script {
      extraArgs = [ "--version-regex=V(.*)" ];
    };
    # goHelpers = buildGoModule {
    #   pname = "mole-helpers";
    #   inherit (finalAttrs) version src;
    #   vendorHash = "";
    #   ldflags = [ "-s" ];
    # };
  };

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "Deep clean and optimize your Mac";
    homepage = "https://github.com/tw93/Mole";
    changelog = "https://github.com/tw93/Mole/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "mole";
    platforms = lib.platforms.darwin;
  };
})
