{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchNpmDeps,
  nodejs,
  npmHooks,
  makeBinaryWrapper,
  versionCheckHook,
  nix-update-script,
}:
let
  # upstream deliberately avoids npm workspaces, so every client keeps its own lockfile
  clients = [
    "web"
    "cli"
    "mcpdo"
    "tui"
    "launcher"
  ];
  # the launcher has no dependencies, its build finds tsc in the root
  clientsWithDeps = lib.remove "launcher" clients;
  # flat passthru names, which `nix-update --custom-dep` can address
  depsAttr = client: "${client}NpmDeps";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "mcp-inspector";
  version = "2.10.1";

  src = fetchFromGitHub {
    owner = "modelcontextprotocol";
    repo = "inspector";
    tag = finalAttrs.version;
    hash = "sha256-dTAD8sBnaAD77fFgrGH/ISRTlXsSur9aLSX+77xouRY=";
  };

  npmDepsHashes = {
    root = "sha256-twig8tHo5mYr4E34HSVkGxg5dEu0/K6RnJ2wlEVzFdU=";
    web = "sha256-mirfNcX4u1NX7m02OqE1w7LK/ReZZ1SDcDxycZgz59Y=";
    cli = "sha256-5TNLH5A6xKhnqVc6I8puwUmkpLIXoDiHH5pdg07fuN0=";
    mcpdo = "sha256-UAlNXRwb9g0mgaxZLnZjMDiyOsmvjk9G83djmlfjDjE=";
    tui = "sha256-MSzCWw7XLxP/Px9lhS/xJVmAIrLSzByXdg+gtfhpJLY=";
  };

  # the root lockfile holds the runtime dependencies of every client
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src;
    hash = finalAttrs.npmDepsHashes.root;
  };

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
    makeBinaryWrapper
  ];

  # the root postinstall would install the clients online, postConfigure does it offline
  env.INSPECTOR_SKIP_CLIENT_INSTALL = "1";

  # npmConfigHook installs the root on its own, the clients reuse it with their own lockfile.
  postConfigure = lib.concatMapStrings (client: ''
    npmRoot=clients/${client} npmDeps=${finalAttrs.passthru.${depsAttr client}} npmConfigHook
  '') clientsWithDeps;

  buildPhase = ''
    runHook preBuild

    # the web build script also type-checks the app, its stories and its tests,
    # which emits nothing
    npm --prefix clients/web run build:client
    npm --prefix clients/web run build:runner

    for client in ${lib.escapeShellArgs (lib.remove "web" clients)}; do
      npm --prefix "clients/$client" run build
    done

    runHook postBuild
  '';

  # the published package ships the client builds next to the root dependencies only
  installPhase = ''
    runHook preInstall

    npm prune --omit=dev

    lib=$out/lib/mcp-inspector
    mkdir -p $lib/clients/web $lib/skills
    cp -r package.json node_modules $lib/
    cp -r skills/mcpdo $lib/skills/
    cp -r clients/web/{build,dist,static} $lib/clients/web/

    for client in ${lib.escapeShellArgs (lib.remove "web" clients)}; do
      mkdir -p "$lib/clients/$client"
      cp -r "clients/$client/build" "$lib/clients/$client/"
    done

    for bin in inspector mcp-inspector; do
      makeBinaryWrapper ${lib.getExe nodejs} "$out/bin/$bin" \
        --add-flags "$lib/clients/launcher/build/index.js"
    done

    makeBinaryWrapper ${lib.getExe nodejs} $out/bin/mcpdo \
      --add-flags "$lib/clients/mcpdo/build/mcp-bin.js"

    runHook postInstall
  '';

  passthru =
    lib.genAttrs' clientsWithDeps (
      client:
      lib.nameValuePair (depsAttr client) (fetchNpmDeps {
        name = "${finalAttrs.pname}-${client}-${finalAttrs.version}-npm-deps";
        inherit (finalAttrs) src;
        sourceRoot = "${finalAttrs.src.name}/clients/${client}";
        hash = finalAttrs.npmDepsHashes.${client};
      })
    )
    // {
      # the root npmDeps is picked up on its own
      updateScript = nix-update-script {
        extraArgs = lib.concatMap (client: [
          "--custom-dep"
          (depsAttr client)
        ]) clientsWithDeps;
      };
    };

  # the launcher has no version flag, mcpdo ships with the same version
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/mcpdo";
  doInstallCheck = true;

  __structuredAttrs = true;

  meta = {
    description = "Visual and command line testing tool for MCP servers";
    homepage = "https://github.com/modelcontextprotocol/inspector";
    changelog = "https://github.com/modelcontextprotocol/inspector/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "mcp-inspector";
  };
})
