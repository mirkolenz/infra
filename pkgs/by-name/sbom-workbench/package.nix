{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
  copyDesktopItems,
  electron,
  makeDesktopItem,
  makeBinaryWrapper,
  nodejs,
  python3,
  removeReferencesTo,
  nix-update-script,
}:
buildNpmPackage (finalAttrs: {
  pname = "sbom-workbench";
  version = "1.41.0";

  src = fetchFromGitHub {
    owner = "scanoss";
    repo = "sbom-workbench";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ghJOcvt+hpUBITbYWd1J4ZxLdkzf8gJiIGQeAJEj5XY=";
  };

  npmDepsHash = "sha256-Uj1Ci3n0fQui9fPGWortrQukFq67q0hyDrwxUTR1/II=";

  # sqlite3 pins node-addon-api 4, which no longer compiles with current clang, so the app lockfile
  # is bumped to the release the current sqlite3 uses
  patches = [ ./node-addon-api.patch ];

  # electron-builder packages `release/app`, which pins the runtime dependencies of the app itself
  # in a second lockfile
  appNpmDeps = fetchNpmDeps {
    inherit (finalAttrs) src patches;
    name = "${finalAttrs.pname}-app-npm-deps";
    sourceRoot = "${finalAttrs.src.name}/release/app";
    # the patch is applied from within the source root here, not from the top of the tree
    patchFlags = [ "-p3" ];
    hash = "sha256-ptMvwIDMUlPZ5NSZqTzEeNH06JBsG4tvs5+zspkDpFM=";
  };

  # both postinstall scripts install and rebuild the app dependencies, which the two npm setup hook
  # runs below do already, and build a development bundle on top
  postPatch = ''
    substituteInPlace package.json release/app/package.json \
      --replace-fail '"postinstall"' '"disabled-postinstall"'
  '';

  # app-builder-lib declares a peer dependency on the windows-only electron-builder-squirrel-windows,
  # which is not part of the lockfile
  npmFlags = [ "--legacy-peer-deps" ];
  makeCacheWritable = true;

  nativeBuildInputs = [
    copyDesktopItems
    makeBinaryWrapper
    python3
    removeReferencesTo
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    # sqlite3 is the only native module and node-pre-gyp would fetch a prebuilt binary for it
    npm_config_build_from_source = "true";
  };

  # makeCacheWritable makes the hook copy its dependencies to $TMPDIR/cache, so the directory of the
  # root package has to go first, or the copy would nest inside it instead of replacing it
  preBuild = ''
    rm -rf "$TMPDIR/cache"
    npmRoot=release/app npmDeps=${finalAttrs.appNpmDeps} npmConfigHook

    # electron-builder packages this tree as it is, so the node-gyp toolchain, the build tree left
    # next to the native module and the store paths that `npmConfigHook` patched into the shebangs
    # of the executables it holds would land in the asar and pin node and python at runtime
    rm -rf \
      release/app/node_modules/node-gyp \
      release/app/node_modules/sqlite3/build-tmp-napi-v6
    find release/app/node_modules -type f -executable \
      -exec remove-references-to -t ${nodejs} {} +
  '';

  postBuild = ''
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      # electron-builder rewrites the Info.plist files of the distribution it is handed
      cp -r ${electron.dist} electron-dist
      chmod -R u+w electron-dist
    ''}

    npm exec electron-builder -- \
      --dir \
      -c.npmRebuild=false \
      -c.electronDist=${if stdenv.hostPlatform.isDarwin then "electron-dist" else electron.dist} \
      -c.electronVersion=${electron.version} \
      ${lib.optionalString stdenv.hostPlatform.isDarwin "-c.mac.identity=null"}
  '';

  installPhase = ''
    runHook preInstall

    ${
      if stdenv.hostPlatform.isDarwin then
        ''
          mkdir -p "$out/Applications"
          mv "release/build/mac"*/*.app "$out/Applications"
          makeBinaryWrapper "$out/Applications/SCANOSS SBOM Workbench.app/Contents/MacOS/SCANOSS SBOM Workbench" \
            "$out/bin/sbom-workbench"
        ''
      else
        ''
          mkdir -p "$out/share/sbom-workbench"
          mv release/build/linux*unpacked/{locales,resources{,.pak}} "$out/share/sbom-workbench"

          makeBinaryWrapper ${lib.getExe electron} "$out/bin/sbom-workbench" \
            --add-flags "$out/share/sbom-workbench/resources/app.asar" \
            --inherit-argv0

          for size in 16 24 32 48 64 96 128 256 512 1024; do
            install -Dm644 "assets/icons/''${size}x''${size}.png" \
              "$out/share/icons/hicolor/''${size}x''${size}/apps/sbom-workbench.png"
          done
        ''
    }

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "sbom-workbench";
      desktopName = "SCANOSS SBOM Workbench";
      comment = finalAttrs.meta.description;
      exec = "sbom-workbench %U";
      icon = "sbom-workbench";
      categories = [ "Development" ];
    })
  ];

  disallowedReferences = [
    nodejs
    python3
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Free of charge, secure and anonymous open source auditing on the desktop";
    homepage = "https://github.com/scanoss/sbom-workbench";
    changelog = "https://github.com/scanoss/sbom-workbench/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "sbom-workbench";
    inherit (electron.meta) platforms;
  };
})
