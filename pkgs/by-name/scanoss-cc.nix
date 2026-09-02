{
  lib,
  stdenv,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
  wails,
  pkg-config,
  webkitgtk_4_1,
  wrapGAppsHook3,
  copyDesktopItems,
  darwin,
  makeDesktopItem,
  makeBinaryWrapper,
  versionCheckHook,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "scanoss-cc";
  version = "0.13.3";

  src = fetchFromGitHub {
    owner = "scanoss";
    repo = "scanoss.cc";
    tag = "v${finalAttrs.version}";
    hash = "sha256-yyPdXcRlIKjcn5TVJG0Ne2W78nY76SsmEasyau2Yono=";
  };

  vendorHash = "sha256-R9J0jk4rSmERGSC0vyGHEye0Xd9wA31RcbQ3WyXyYZw=";

  nativeBuildInputs = [
    wails
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    darwin.system_cmds # sysctl, used by wails to detect the build machine
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    copyDesktopItems
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    webkitgtk_4_1
  ];

  # the application icon is embedded from the build directory, which upstream fills in its makefile
  preBuild = ''
    cp -r ${finalAttrs.passthru.frontend} frontend/dist
    install -Dm644 assets/* -t build/assets
    install -Dm644 assets/appicon.png build/appicon.png
  '';

  buildPhase = ''
    runHook preBuild

    export HOME="$(mktemp -d)"
    wails build -m -s -trimpath -skipbindings \
      ${lib.optionalString stdenv.hostPlatform.isLinux "-tags webkit2_41"} \
      -ldflags "-X github.com/scanoss/scanoss.cc/backend/entities.AppVersion=${finalAttrs.version}"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    ${
      if stdenv.hostPlatform.isDarwin then
        ''
          mkdir -p "$out/Applications"
          cp -r build/bin/scanoss-cc.app "$out/Applications"
          makeBinaryWrapper "$out/Applications/scanoss-cc.app/Contents/MacOS/scanoss-cc" "$out/bin/scanoss-cc"
        ''
      else
        ''
          install -Dm755 build/bin/scanoss-cc "$out/bin/scanoss-cc"
          install -Dm644 build/appicon.png "$out/share/icons/hicolor/512x512/apps/scanoss-cc.png"
        ''
    }

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "scanoss-cc";
      desktopName = "SCANOSS Code Compare";
      comment = "Review and decide on SCANOSS scan results";
      exec = "scanoss-cc";
      icon = "scanoss-cc";
      categories = [ "Development" ];
    })
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru = {
    # wails would install and build this itself, which needs network access, so it is built here and
    # handed to `wails build -s` above
    frontend = buildNpmPackage {
      pname = "scanoss-cc-frontend";
      inherit (finalAttrs) version src;

      sourceRoot = "${finalAttrs.src.name}/frontend";

      npmDepsHash = "sha256-18pqRs4PNpx7/1xsYaJWFzcnFAt0gvEvjP02QFvmMyc=";

      # the default build script also runs a type check, which the bundle does not need
      npmBuildScript = "build-only";

      installPhase = ''
        runHook preInstall

        cp -r dist $out

        runHook postInstall
      '';
    };

    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage"
        "frontend"
      ];
    };
  };

  meta = {
    description = "Lightweight desktop application to review the results of a SCANOSS scan";
    homepage = "https://github.com/scanoss/scanoss.cc";
    changelog = "https://github.com/scanoss/scanoss.cc/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "scanoss-cc";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
})
