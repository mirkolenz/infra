{
  lib,
  stdenvNoCC,
  fetchurl,
  patchelf-fixed,
  autoPatchelfHook,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  makeShellWrapper,
  installShellFiles,
  writeShellApplication,
  cacert,
  curl,
  jq,
  zstd,
  bubblewrap,
  socat,
  procps,
  unzip,
  ripgrep,
  alsa-lib,
  updateChannel ? "latest",
  manifestFile ? ./manifest.json,
}:
let
  baseUrl = "https://downloads.claude.ai/claude-code-releases";
  manifest = lib.importJSON manifestFile;
  platforms = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    aarch64-darwin = "darwin-arm64";
  };
  platform = platforms.${stdenvNoCC.hostPlatform.system};
  platformManifest = manifest.platforms.${platform};
  inherit (stdenvNoCC.hostPlatform) isLinux;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "claude-code";
  version = manifest.version or "unstable";

  src = fetchurl {
    url = "${baseUrl}/${finalAttrs.version}/${platform}/${platformManifest.binary}";
    sha256 = platformManifest.checksum;
  };

  unpackCmd = "unzstd $curSrc -o claude";
  sourceRoot = ".";

  dontBuild = true;
  # otherwise the bun runtime is executed instead of the binary (on linux)
  dontStrip = true;

  nativeBuildInputs = [
    installShellFiles
    makeShellWrapper
    zstd
  ]
  ++ lib.optionals isLinux [
    autoPatchelfHook
    patchelf-fixed
  ];

  installPhase = ''
    runHook preInstall

    installBin claude

    # on darwin, the system cert store only reads the keychain search list without the Apple roots,
    # so add the CA bundle of nix (e.g., from nix-darwin) unless the user provides extra certs
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
      --set USE_BUILTIN_RIPGREP 0 \
      --set-default CLAUDE_CODE_CERT_STORE system \
      --run 'export NODE_EXTRA_CA_CERTS=''${NODE_EXTRA_CA_CERTS-''${NIX_SSL_CERT_FILE-}}' \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            # process tree inspection
            procps
            # https://code.claude.com/docs/en/troubleshooting#search-and-discovery-issues
            ripgrep
            # extraction of plugin archives from claude.ai
            unzip
          ]
          # https://code.claude.com/docs/en/sandboxing#prerequisites
          ++ lib.optionals isLinux [
            bubblewrap
            socat
          ]
        )
      } \
      ${lib.optionalString isLinux "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ alsa-lib ]}"}

    runHook postInstall
  '';

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  doInstallCheck = true;

  strictDeps = true;
  __structuredAttrs = true;

  passthru.updateScript = lib.getExe (writeShellApplication {
    name = "update-claude-code";
    runtimeInputs = [
      curl
      jq
    ];
    runtimeEnv.SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    text = ''
      # https://claude.ai/install.sh
      version="$(curl -fsSL --compressed "${baseUrl}/${updateChannel}")"

      manifest="$(
        curl -fsSL --compressed "${baseUrl}/$version/manifest.zst.json" \
        | jq --argjson platforms '${builtins.toJSON (lib.attrValues platforms)}' '{
          version,
          platforms: .platforms | with_entries(
            select(.key | IN($platforms[])) | .value |= { binary, checksum }
          )
        }'
      )"
      echo "$manifest" > "${toString manifestFile}"
    '';
  });

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://claude.com/product/claude-code";
    changelog = "https://github.com/anthropics/claude-code/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ mirkolenz ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "claude";
    platforms = lib.attrNames platforms;
    # only a download, not worth the cache space a frequent bump takes
    hydraPlatforms = [ ];
  };
})
