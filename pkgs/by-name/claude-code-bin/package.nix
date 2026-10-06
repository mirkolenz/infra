{
  lib,
  stdenvNoCC,
  fetchurl,
  buildPackages,
  autoPatchelfHook,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  makeBinaryWrapper,
  installShellFiles,
  writeShellApplication,
  cacert,
  curl,
  jq,
  zstd,
  bubblewrap,
  socat,
  procps,
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
  # drop the patch once nixpkgs' patchelf includes NixOS/patchelf#665
  patchelf = buildPackages.patchelf.overrideAttrs (old: {
    patches = old.patches or [ ] ++ [ ./patchelf-update-dt-verdef.patch ];
  });
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
  __noChroot = stdenvNoCC.hostPlatform.isDarwin;
  # otherwise the bun runtime is executed instead of the binary (on linux)
  dontStrip = true;

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
    zstd
  ]
  ++ lib.optionals isLinux [
    autoPatchelfHook
    patchelf
  ];

  # DT_RPATH (not DT_RUNPATH) so the dlopen'd audio-capture.node finds libasound
  runtimeDependencies = lib.optionals isLinux [ alsa-lib ];
  patchelfFlags = [ "--force-rpath" ];

  installPhase = ''
    runHook preInstall

    installBin claude

    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
      --set USE_BUILTIN_RIPGREP 0 \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            # https://github.com/pkrumins/node-tree-kill requires procps
            procps
            # https://code.claude.com/docs/en/troubleshooting#search-and-discovery-issues
            ripgrep
          ]
          # https://code.claude.com/docs/en/sandboxing#prerequisites
          ++ lib.optionals isLinux [
            bubblewrap
            socat
          ]
        )
      }

    runHook postInstall
  '';

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  doInstallCheck = true;
  postInstallCheck = lib.optionalString isLinux ''
    readelf -dW $out/bin/.claude-wrapped | grep -q '(RPATH).*${lib.getLib alsa-lib}/lib'
  '';

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
        | jq '{
          version,
          platforms: .platforms | with_entries(
            select(.key | test("^(darwin|linux)-(x64|arm64)$"))
            | {
              key,
              value: { binary: .value.binary, checksum: .value.checksum }
            }
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
