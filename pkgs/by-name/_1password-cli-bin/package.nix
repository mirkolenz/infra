{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  installShellFiles,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  writeShellApplication,
  cacert,
  curl,
  jq,
  beta ? true,
  manifestFile ? ./manifest.json,
}:
let
  manifest = lib.importJSON manifestFile;
  platforms = {
    x86_64-linux = "linux_amd64";
    aarch64-linux = "linux_arm64";
    aarch64-darwin = "darwin_arm64";
  };
  platform = platforms.${stdenvNoCC.hostPlatform.system};
  mkUrl =
    version: platform:
    "https://cache.agilebits.com/dist/1P/op2/pkg/v${version}/op_${platform}_v${version}.zip";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "1password-cli";
  version = manifest.version or "unstable";

  src = fetchurl {
    url = mkUrl finalAttrs.version platform;
    hash = manifest.hashes.${platform};
  };

  sourceRoot = ".";

  dontBuild = true;
  # keeps the code signature on darwin that the app integration verifies
  dontStrip = true;

  nativeBuildInputs = [
    installShellFiles
    unzip
    writableTmpDirAsHomeHook
  ];

  installPhase = ''
    runHook preInstall

    installBin op
    ${lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
      installShellCompletion --cmd op \
        --bash <($out/bin/op completion bash) \
        --fish <($out/bin/op completion fish) \
        --zsh <($out/bin/op completion zsh)
    ''}

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckKeepEnvironment = [ "HOME" ];
  doInstallCheck = true;

  strictDeps = true;
  __structuredAttrs = true;

  passthru.updateScript = lib.getExe (writeShellApplication {
    name = "update-1password-cli";
    runtimeInputs = [
      curl
      jq
    ];
    runtimeEnv.SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    text = ''
      # the update feed of agilebits, Y for the beta and N for the stable channel
      version="$(
        curl -fsSL "https://app-updates.agilebits.com/check/1/0/CLI2/en/0/${if beta then "Y" else "N"}" \
        | jq -r .version
      )"

      if [[ "$version" == "${finalAttrs.version}" ]]; then
        exit 0
      fi

      # agilebits publishes no checksums, so hash the archives with the nix of the caller
      for platform in ${lib.escapeShellArgs (lib.attrValues platforms)}; do
        nix store prefetch-file --json "${mkUrl "\${version}" "\${platform}"}" \
        | jq --arg platform "$platform" '{ ($platform): .hash }'
      done \
      | jq -s --arg version "$version" '{ version: $version, hashes: add }' \
      > "${toString manifestFile}"
    '';
  });

  meta = {
    description = "1Password command-line tool";
    homepage = "https://developer.1password.com/docs/cli";
    downloadPage = "https://app-updates.agilebits.com/product_history/CLI2";
    changelog = "https://releases.1password.com/developers/cli";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ mirkolenz ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "op";
    platforms = lib.attrNames platforms;
    # only a download, not worth the cache space a frequent bump takes
    hydraPlatforms = [ ];
  };
})
