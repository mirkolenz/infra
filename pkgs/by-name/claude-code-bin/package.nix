{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  makeBinaryWrapper,
  installShellFiles,
  writeScript,
  bubblewrap,
  socat,
  procps,
  ripgrep,
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
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "claude-code";
  version = manifest.version or "unstable";

  src = fetchurl {
    url = "${baseUrl}/${finalAttrs.version}/${platform}/claude";
    sha256 = manifest.platforms.${platform}.checksum;
  };

  dontUnpack = true;
  dontBuild = true;
  __noChroot = stdenvNoCC.hostPlatform.isDarwin;

  # otherwise the bun runtime is executed instead of the binary (on linux)
  dontStrip = true;

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isElf [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    installBin $src
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
          ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [
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

  strictDeps = true;
  __structuredAttrs = true;

  passthru.updateScript = writeScript "update-claude-code" ''
    #!/usr/bin/env nix-shell
    #!nix-shell --pure -i bash -p curl jq cacert

    set -euo pipefail

    # https://claude.ai/install.sh
    version="$(curl -fsSL "${baseUrl}/${updateChannel}")"
    manifest="$(
      curl -fsSL "${baseUrl}/$version/manifest.json" \
      | jq '{
        version,
        platforms: .platforms | with_entries(
          select(.key | test("^(darwin|linux)-(x64|arm64)$"))
          | {
            key,
            value: { checksum: .value.checksum }
          }
        )
      }'
    )"
    echo "$manifest" > "${toString manifestFile}"
  '';

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://claude.com/product/claude-code";
    changelog = "https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ mirkolenz ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "claude";
    platforms = lib.attrNames platforms;
  };
})
