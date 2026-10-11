{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  makeBinaryWrapper,
  installShellFiles,
  writeShellApplication,
  cacert,
  curl,
  jq,
  unzip,
  ripgrep,
  updateChannel ? "latest",
  manifestFile ? ./manifest.json,
}:
let
  manifest = lib.importJSON manifestFile;
  platforms = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    aarch64-darwin = "darwin-arm64";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = manifest.version or "unstable";

  src = fetchurl {
    inherit (manifest.platforms.${platforms.${stdenvNoCC.hostPlatform.system}}) url sha256;
  };

  sourceRoot = ".";

  dontBuild = true;
  # otherwise the bun runtime is executed instead of the binary (on linux)
  dontStrip = true;

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
    unzip
    writableTmpDirAsHomeHook
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    installBin opencode

    wrapProgram $out/bin/opencode \
      --set OPENCODE_DISABLE_AUTOUPDATE 1 \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  # a post-phase, so autoPatchelfHook has already patched the binary on linux
  postPhases = lib.optionals (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) [
    "installCompletionPhase"
  ];
  # opencode creates $TMPDIR/opencode on startup, which collides with the
  # unpacked binary of the same name in the build dir (TMPDIR == NIX_BUILD_TOP).
  installCompletionPhase = ''
    TMPDIR=$(mktemp -d)

    for shell in bash fish zsh; do
      $out/bin/opencode --completions $shell > opencode.$shell
    done

    installShellCompletion opencode.{bash,fish,zsh}
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckKeepEnvironment = [ "HOME" ];
  doInstallCheck = true;

  strictDeps = true;
  __structuredAttrs = true;

  passthru.updateScript = lib.getExe (writeShellApplication {
    name = "update-opencode";
    runtimeInputs = [
      curl
      jq
    ];
    runtimeEnv.SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    text = ''
      # https://github.com/anomalyco/opencode/blob/v2/services/update/README.md
      manifest="$(
        curl -fsSL --compressed "https://opencode.ai/update/api/${updateChannel}/cli/opencode" \
        | jq --argjson platforms '${builtins.toJSON (lib.attrValues platforms)}' '{
          version,
          platforms: .metadata.files | with_entries(
            .key |= capture("^opencode-(?<platform>[^.]+)\\.").platform
            | select(.key | IN($platforms[]))
            | .value |= { url, sha256 }
          )
        }'
      )"
      echo "$manifest" > "${toString manifestFile}"
    '';
  });

  meta = {
    description = "Open source coding agent";
    homepage = "https://opencode.ai";
    changelog = "https://github.com/anomalyco/opencode/commits/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "opencode";
    platforms = lib.attrNames platforms;
    # only a download, not worth the cache space a frequent bump takes
    hydraPlatforms = [ ];
  };
})
