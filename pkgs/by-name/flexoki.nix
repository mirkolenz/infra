{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "flexoki";
  version = "2.0.0-unstable-2026-03-07";

  src = fetchFromGitHub {
    owner = "kepano";
    repo = "flexoki";
    rev = "8d723bac4a9ac46adfdf99d42155286977aac72a";
    hash = "sha256-IxnvoZ9hGEvwq/PBbHTL5L2a2kxMSXSINIfd5Dg9ttA=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    cp -r [!_]* $out/share/

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "An inky color scheme for prose and code";
    homepage = "https://github.com/kepano/flexoki";
    changelog = "https://github.com/kepano/flexoki/releases";
    downloadPage = "https://github.com/kepano/flexoki/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
})
