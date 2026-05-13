{
  lib,
  stdenvNoCC,
  fetchzip,
  nix-update-script,
  makeBinaryWrapper,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ollama";
  version = "0.23.3";

  src = fetchzip {
    url = "https://github.com/ollama/ollama/releases/download/v${finalAttrs.version}/ollama-darwin.tgz";
    hash = "sha256-uu5cNy5XiVleS15l0QwfdfI4kqUNKiiIyh5tPSf8Hy8=";
    stripRoot = false;
  };

  dontConfigure = true;
  dontBuild = true;
  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [
    makeBinaryWrapper
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec
    cp -r $src/* $out/libexec/
    makeWrapper $out/libexec/ollama $out/bin/ollama

    runHook postInstall
  '';

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  doInstallCheck = true;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Get up and running with Kimi-K2.5, GLM-5, MiniMax, DeepSeek, gpt-oss, Qwen, Gemma and other models";
    homepage = "https://github.com/ollama/ollama";
    downloadPage = "https://github.com/ollama/ollama/releases";
    mainProgram = "ollama";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ mirkolenz ];
    platforms = lib.platforms.darwin;
  };
})
