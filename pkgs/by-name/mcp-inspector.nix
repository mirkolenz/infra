{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
  nodejs,
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
buildNpmPackage (finalAttrs: {
  pname = "mcp-inspector";
  version = "2.17.0";

  src = fetchFromGitHub {
    owner = "modelcontextprotocol";
    repo = "inspector";
    tag = finalAttrs.version;
    hash = "sha256-XRcz1Z7Aj92Q3lWel9mm/1GnZ6ywxL/WH5/hRR7un5I=";
  };

  # the root lockfile holds the runtime dependencies of every client
  npmDepsHash = "sha256-WeaWA/85uIIPgzK7keT46TIwPVXitPtUHE5huxDWHVQ=";

  npmDepsHashes = {
    web = "sha256-k8uI5cSuhEKAMFl+UMPElvu9RB9zbapwp+yd/4PJX7A=";
    cli = "sha256-Fbi/6HLq4Q6sSgUeySa66LDHepcA5GdvsR9RIMHOubE=";
    mcpdo = "sha256-ikB1o5YxQ8qO3VTtY3F8cNY9Sycx09L0vttetA2QEkw=";
    tui = "sha256-q5MDOAxiESmoH3Z91uzFi9FlwTOR9a9mo6Qtx1oi9Tg=";
  };

  nativeBuildInputs = [ makeBinaryWrapper ];

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
