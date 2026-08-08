{
  writeScript,
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
    }:
    let
      jqSelector = if allowPrereleases then ".[0]" else ".";
      ghCall =
        if allowPrereleases then
          "gh api repos/${owner}/${repo}/releases --method GET --raw-field per_page=1"
        else
          "gh api repos/${owner}/${repo}/releases/latest";

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

      installPhase = ''
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
        updateScript = writeScript "github-binaries-${owner}-${repo}" ''
          #!/usr/bin/env nix-shell
          #!nix-shell --pure --keep GH_TOKEN -i bash -p gh jq

          set -euo pipefail

          output="$(
            ${ghCall} \
            | jq --argjson sentinelNames '${sentinelAssetNames}' '
              ${jqSelector} |
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
            '
          )"

          echo "$output" > "${toString file}"
        '';
      }
      // passthru;

      meta = {
        homepage = "https://github.com/${owner}/${repo}";
        changelog = "https://github.com/${owner}/${repo}/releases";
        downloadPage = "https://github.com/${owner}/${repo}/releases/tag/${release.tag_name}";
        maintainers = with lib.maintainers; [ mirkolenz ];
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
        mainProgram = finalAttrs.pname;
        platforms = lib.attrNames resolvedAssets;
      }
      // meta;
    };
}
