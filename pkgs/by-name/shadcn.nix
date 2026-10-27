{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  makeBinaryWrapper,
  jq,
  moreutils,
  yq,
  versionCheckHook,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "shadcn";
  version = "4.22.2";

  src = fetchFromGitHub {
    owner = "shadcn-ui";
    repo = "ui";
    tag = "shadcn@${finalAttrs.version}";
    hash = "sha256-Ji5oybhzb4WZl49WuOf51gxJsZbuPEq5huijTjIJNLc=";
  };

  pnpmWorkspaces = [ "shadcn..." ];

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
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-HOXQTK9tq0KZe/dWF1RE4GVvW2wDzPyyQXBQkfFPdyc=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm_10
    pnpmConfigHook
    makeBinaryWrapper
    jq
    moreutils
    yq
  ];

  # the cli depends on the `@shadcn/registry` workspace package, which `shadcn...`
  # builds first
  buildPhase = ''
    runHook preBuild

    pnpm --filter "shadcn..." run build

    runHook postBuild
  '';

  # keep the workspace layout, so the links of the cli to its sibling and to the
  # hoisted dependencies stay valid, but only with the production dependencies
  installPhase = ''
    runHook preInstall

    rm -rf node_modules packages/*/node_modules
    pnpm install --offline --frozen-lockfile --ignore-scripts --prod --filter "shadcn..."

    mkdir -p $out/lib/shadcn/packages/{shadcn,registry}
    cp -r node_modules $out/lib/shadcn/node_modules

    for pkg in shadcn registry; do
      cp -r packages/$pkg/{dist,node_modules,package.json} $out/lib/shadcn/packages/$pkg/
    done

    # the farm also links the other workspace packages, which the cli does not load
    find $out/lib/shadcn -xtype l -delete

    makeBinaryWrapper ${lib.getExe nodejs} $out/bin/shadcn \
      --add-flags $out/lib/shadcn/packages/shadcn/dist/index.js

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version-regex=shadcn@(.*)" ];
  };

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  __structuredAttrs = true;

  meta = {
    description = "CLI to add shadcn/ui components and registry items to a project";
    homepage = "https://ui.shadcn.com/docs/cli";
    changelog = "https://github.com/shadcn-ui/ui/blob/${finalAttrs.src.tag}/packages/shadcn/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "shadcn";
  };
})
