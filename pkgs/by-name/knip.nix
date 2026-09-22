{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  pnpm_11,
  pnpmConfigHook,
  makeWrapper,
  versionCheckHook,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "knip";
  version = "6.37.0";

  src = fetchFromGitHub {
    owner = "webpro-nl";
    repo = "knip";
    tag = "knip@${finalAttrs.version}";
    hash = "sha256-epod0JsCZ2oemoqzK7GRzFUg0OwEunqSOsAl3kr09H8=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-73rus7YYjl3bDkiVobo5eWAoceqodlpaimxDv/a3V3o=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm_11
    pnpmConfigHook
    makeWrapper
  ];

  # `build` also triggers the package's `prebuild`, which generates the plugin
  # definitions that `tsc` then needs
  buildPhase = ''
    runHook preBuild

    pnpm --filter knip run build

    runHook postBuild
  '';

  # a pnpm workspace resolves dependencies through a symlink farm under the workspace
  # root, and each package in it relies on its siblings being reachable from the same
  # directory. `pnpm deploy` would flatten that, but re-resolves against the registry,
  # which the offline store cannot answer, so keep the workspace layout verbatim and
  # let the relative links stay valid.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/knip/packages/knip
    cp -r node_modules $out/lib/knip/node_modules
    cp -r packages/knip/{dist,bin,node_modules,package.json,schema.json,schema-jsonc.json} \
      $out/lib/knip/packages/knip/

    # the farm also links the sibling workspace packages, the docs site, the vscode
    # extension and the language server, none of which the cli loads
    find $out/lib/knip -xtype l -delete

    makeWrapper ${lib.getExe nodejs} $out/bin/knip \
      --add-flags $out/lib/knip/packages/knip/bin/knip.js

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version-regex=knip@(.*)" ];
  };

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  __structuredAttrs = true;

  meta = {
    description = "Finds unused files, dependencies and exports in JavaScript and TypeScript projects";
    homepage = "https://knip.dev";
    changelog = "https://github.com/webpro-nl/knip/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.isc;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "knip";
  };
})
