{
  writeShellApplication,
  cacert,
  curl,
  jq,
  lib,
  fetchurl,
  stdenv,
  installShellFiles,
  autoPatchelfHook,
}:
lib.extendMkDerivation {
  constructDrv = stdenv.mkDerivation;
  excludeDrvArgNames = [
    "owner"
    "repo"
    "file"
    "assets"
    "binaries"
    "versionPrefix"
    "versionSuffix"
    "allowPrereleases"
  ];
  extendDrvArgs =
    finalAttrs:
    {
      # custom
      owner,
      repo,
      file,
      assets,
      binaries ? [ finalAttrs.pname ],
      versionPrefix ? "",
      versionSuffix ? "",
      allowPrereleases ? false,
      # Scheduled as a post-phase (runs after fixupPhase) so the binary is
      # already patched by autoPatchelfHook when the snippet executes it.
      installShellCompletionPhase ? "",
      # upstream
      pname ? repo,
      nativeBuildInputs ? [ ],
      passthru ? { },
      meta ? { },
      ...
    }@args:
    let
      # The prerelease endpoint returns a list, hence the differing selector.
      api =
        if allowPrereleases then
          {
            url = "https://api.github.com/repos/${owner}/${repo}/releases?per_page=1";
            selector = ".[0]";
          }
        else
          {
            url = "https://api.github.com/repos/${owner}/${repo}/releases/latest";
            selector = ".";
          };

      release = lib.importJSON file;

      # Assets can be an attrset or a function of version, mapping each system
      # to a single asset name or a list of them.
      resolvedAssets = if lib.isFunction assets then assets finalAttrs.version else assets;

      # Evaluate assets with a sentinel version to obtain name templates.
      # The update script replaces the sentinel with the actual version for
      # exact name matching against the release assets.
      sentinel = "__NIXPKGS_VERSION__";
      sentinelAssets = if lib.isFunction assets then assets sentinel else assets;
      sentinelAssetNames = lib.toJSON (lib.flatten (lib.attrValues sentinelAssets));

      jqVersionExpr = lib.concatStrings [
        ".tag_name"
        (lib.optionalString (versionPrefix != "") " | ltrimstr(\"${versionPrefix}\")")
        (lib.optionalString (versionSuffix != "") " | rtrimstr(\"${versionSuffix}\")")
      ];

      assetNames = lib.toList resolvedAssets.${stdenv.hostPlatform.system};

      # Binaries can be a list of names, or an attrset mapping each installed
      # name to its path in the unpacked sources when the two differ.
      binaryPaths = if lib.isList binaries then lib.genAttrs binaries lib.id else binaries;
    in
    {
      inherit pname;
      version = lib.pipe (release.tag_name or "unstable") [
        (lib.removePrefix versionPrefix)
        (lib.removeSuffix versionSuffix)
      ];

      srcs = map (
        name:
        fetchurl {
          url = "https://github.com/${owner}/${repo}/releases/download/${release.tag_name}/${name}";
          hash = release.assets.${name}.digest;
        }
      ) assetNames;

      dontConfigure = true;
      dontBuild = true;
      strictDeps = true;
      __structuredAttrs = true;

      nativeBuildInputs =
        nativeBuildInputs
        ++ [ installShellFiles ]
        ++ lib.optionals stdenv.hostPlatform.isElf [ autoPatchelfHook ];

      # Packages may replace the default installation of the listed binaries.
      installPhase =
        args.installPhase or ''
          runHook preInstall

          ${lib.concatLines (
            lib.mapAttrsToList (name: path: ''install -Dm755 "${path}" "$out/bin/${name}"'') binaryPaths
          )}

          runHook postInstall
        '';

      postPhases = lib.optionals (installShellCompletionPhase != "") [
        "installShellCompletionPhase"
      ];

      passthru = {
        updateScript = lib.getExe (writeShellApplication {
          name = "github-binaries-${owner}-${repo}";
          runtimeInputs = [
            curl
            jq
          ];
          runtimeEnv.SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
          text = ''
            auth=()

            if [[ -n "''${GITHUB_TOKEN:-}" ]]; then
              auth=(--user ":$GITHUB_TOKEN")
            fi

            if ! response="$(
              curl --silent --show-error --fail-with-body --location --compressed \
                --header "Accept: application/vnd.github+json" \
                --header "X-GitHub-Api-Version: 2026-03-10" \
                "''${auth[@]}" \
                "${api.url}"
            )"; then
              echo "$response" >&2
              exit 1
            fi

            output="$(
              jq --argjson sentinelNames '${sentinelAssetNames}' '
                ${api.selector} |
                (${jqVersionExpr}) as $version |
                INDEX(.assets[]; .name) as $assets | {
                  tag_name,
                  assets: [
                    $sentinelNames[] as $sentinelName |
                    ($sentinelName | split("${sentinel}") | join($version)) as $name |
                    ($assets[$name] // error("Asset not found: \($name)")) |
                    { key: .name, value: { digest } }
                  ] | from_entries
                }
              ' <<<"$response"
            )"

            echo "$output" > "${toString file}"
          '';
        });
      }
      // passthru;

      meta = {
        homepage = "https://github.com/${owner}/${repo}";
        changelog = "https://github.com/${owner}/${repo}/releases/tag/${release.tag_name}";
        maintainers = with lib.maintainers; [ mirkolenz ];
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
        mainProgram = finalAttrs.pname;
        platforms = lib.attrNames resolvedAssets;
      }
      // meta;
    };
}
