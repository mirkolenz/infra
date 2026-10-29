{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  pnpm_11,
  pnpmConfigHook,
  makeBinaryWrapper,
  jq,
  moreutils,
  yq,
  versionCheckHook,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "knip";
  version = "6.44.0";

  src = fetchFromGitHub {
    owner = "webpro-nl";
    repo = "knip";
    tag = "knip@${finalAttrs.version}";
    hash = "sha256-ZOhxrDkPgKiwrcldkqnW08Vvy48kxjjhrESaFUhwWtc=";
  };

  pnpmWorkspaces = [ "knip" ];

  # pnpm always installs the workspace root, which holds the repository tooling,
  # so it is dropped from the manifest and the lockfile importer with the tools
  # that `fetchPnpmDeps` provides
  prePnpmInstall = ''
    jq 'del(.dependencies, .devDependencies)' package.json | sponge package.json
    yq -yi 'del(.importers["."].dependencies, .importers["."].devDependencies)' pnpm-lock.yaml
  '';

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      pnpmWorkspaces
      prePnpmInstall
      ;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-tmrU7a04HuninwTr61NeqFaBFySy1T9qLwm/pFhx0dI=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm_11
    pnpmConfigHook
    makeBinaryWrapper
    jq
    moreutils
    yq
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
  # let the relative links stay valid. The workspace install also holds the build
  # toolchain, so only the production dependencies of the cli are reinstalled.
  installPhase = ''
    runHook preInstall

    rm -rf node_modules packages/*/node_modules
    pnpm install --offline --frozen-lockfile --ignore-scripts --prod --filter knip

    mkdir -p $out/lib/knip/packages/knip
    cp -r node_modules $out/lib/knip/node_modules
    cp -r packages/knip/{dist,bin,node_modules,package.json,schema.json,schema-jsonc.json} \
      $out/lib/knip/packages/knip/

    # the farm also links the sibling workspace packages, the docs site, the vscode
    # extension and the language server, none of which the cli loads
    find $out/lib/knip -xtype l -delete

    makeBinaryWrapper ${lib.getExe nodejs} $out/bin/knip \
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
