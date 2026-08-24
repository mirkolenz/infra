{
  lib,
  stdenvNoCC,
  mkHerdrPlugin,
  fetchFromGitHub,
  nix-update-script,
  writableTmpDirAsHomeHook,
  bashNonInteractive,
  bat,
  bun,
  coreutils,
  fzf,
  gh,
  gitMinimal,
}:
mkHerdrPlugin (finalAttrs: {
  pname = "herdr-sessionizer";
  version = "0.8.0";
  pluginId = "sessionizer";

  src = fetchFromGitHub {
    owner = "andrewchng";
    repo = "herdr-sessionizer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-MfR5n+hPMd1FYIJrI+oZt9aJNNAo/TvldjwQJpPI4TM=";
  };

  interpreters = [ bun ];
  pluginFiles = [
    "package.json"
    "src"
  ];
  runtimeInputs = [
    bashNonInteractive
    bat
    coreutils
    fzf
    gh
    gitMinimal
  ];

  nativeCheckInputs = [ bun ];
  doCheck = true;
  preCheck = ''ln -s ${finalAttrs.passthru.nodeModules} node_modules'';
  # upstream's `test` script skips the integration tests, which drive fzf against
  # a live herdr session
  checkPhase = ''
    runHook preCheck

    bun run test

    runHook postCheck
  '';

  postInstall = ''
    ln -s ${finalAttrs.passthru.nodeModules} "$root/node_modules"
  '';

  passthru = {
    nodeModules = stdenvNoCC.mkDerivation {
      pname = "${finalAttrs.pname}-node-modules";
      inherit (finalAttrs) version src;

      impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
        "GIT_PROXY_COMMAND"
        "SOCKS_SERVER"
      ];
      nativeBuildInputs = [
        bun
        writableTmpDirAsHomeHook
      ];

      dontConfigure = true;
      buildPhase = ''
        runHook preBuild

        export BUN_INSTALL_CACHE_DIR="$(mktemp -d)"
        bun install --frozen-lockfile --ignore-scripts --no-progress --production

        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall

        mv node_modules "$out"

        runHook postInstall
      '';

      dontFixup = true;
      outputHash = "sha256-ffUrt3+NQRWz3Lcf0g16zqseC/5XzWp26eK3ybjh1Gk=";
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
    };

    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage"
        "nodeModules"
      ];
    };
  };

  meta = {
    description = "Fuzzy project and worktree launcher for herdr";
    homepage = "https://github.com/andrewchng/herdr-sessionizer";
    changelog = "https://github.com/andrewchng/herdr-sessionizer/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
  };
})
