{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  nix-update-script,
}:
# the cli half of legalviz.eu, which is the only command line client for EUR-Lex that
# exists: it resolves references to CELEX, downloads the Formex source and hands back
# structured json in any of the 24 official languages
buildNpmPackage (finalAttrs: {
  pname = "eurlex";
  version = "fulltext-2026-09-05.01-unstable-2026-09-09";

  src = fetchFromGitHub {
    owner = "maastrichtlawtech";
    repo = "legalviz.eu";
    rev = "601cc76b8f5bd106315bbf7b5cbcdc36b64e8939";
    hash = "sha256-NVkU5ethmaIOOm5Akuf+N+3jsngG2Ea52rgqEiZny+o=";
  };

  sourceRoot = "${finalAttrs.src.name}/backend";

  npmDepsHash = "sha256-SkJjU/Jd8XB/N68HG8czFJ8lT65Z5FYhzRXkOIQ/Pic=";

  # the package is the api server as well as the cli, so it pulls a browser driver in
  # that neither half needs at install time
  env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

  # better-sqlite3 is the only native dependency and builds from source here
  nativeBuildInputs = [ python3 ];

  # `CACHE_DIR` and `FMX_DIR` already override the Formex cache, but their fallback is a
  # directory next to the module, which here is the read-only store path. Only that
  # default is replaced. A wrapper cannot supply it: makeBinaryWrapper has no `--run`,
  # and its `--set-default` bakes the value in literally, so neither XDG_CACHE_HOME nor
  # HOME would expand. Resolving it in node is also one process fewer at runtime.
  # The search index path stays as upstream ships it, since it is only ever read.
  postPatch = ''
    substituteInPlace bin/eurlex.js \
      --replace-fail "path.join(__dirname, '..', 'law-cache')" \
        "path.join(process.env.XDG_CACHE_HOME || path.join(require('os').homedir(), '.cache'), 'eurlex')"
  '';

  dontNpmBuild = true;

  # node-gyp leaves its intermediates next to the addon, and the Makefile and
  # config.gypi in there spell out the python and npm-deps store paths, which pins a
  # full build toolchain into the runtime closure. Only the compiled addon is loaded.
  postInstall = ''
    build=$out/lib/node_modules/legalviz-backend/node_modules/better-sqlite3/build
    addon=$(mktemp -d)/better_sqlite3.node
    mv "$build/Release/better_sqlite3.node" "$addon"
    rm -rf "$build"
    mkdir -p "$build/Release"
    mv "$addon" "$build/Release/better_sqlite3.node"
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };

  # the package states no version of its own, so there is nothing for
  # versionCheckHook to match; check that the cli runs at all instead
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    $out/bin/eurlex --help > /dev/null

    runHook postInstallCheck
  '';

  __structuredAttrs = true;

  meta = {
    description = "Command line client for EU legislation, resolving references to CELEX and returning structured JSON";
    homepage = "https://legalviz.eu";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "eurlex";
  };
})
