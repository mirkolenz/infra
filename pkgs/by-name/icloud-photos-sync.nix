{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_26,
  versionCheckHook,
  nix-update-script,
}:
buildNpmPackage (finalAttrs: {
  pname = "icloud-photos-sync";
  version = "5.0.1";

  src = fetchFromGitHub {
    owner = "steilerDev";
    repo = "icloud-photos-sync";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/gVhMHePsaHIWTNLP3+QyFKzfgFQ37YM0wJvg8KUk3o=";
  };

  sourceRoot = "${finalAttrs.src.name}/app";

  npmDepsHash = "sha256-ge7r8N1K2k40+8cmB1vNm9yBxMoiDDxZU+LDRIEK9m0=";

  nodejs = nodejs_26;

  # upstream versions the package at release time only
  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"version": "0.0.0-development"' '"version": "${finalAttrs.version}"'
  '';

  # `build` would lint first, `dist:package` moves the compiled sources into `bin`
  npmBuildScript = "build:dev";

  postBuild = ''
    npm run dist:package
  '';

  passthru.updateScript = nix-update-script { };

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "One-way sync engine for the iCloud Photos Library into the native file system";
    homepage = "https://icps.steiler.dev";
    changelog = "https://github.com/steilerDev/icloud-photos-sync/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "icloud-photos-sync";
  };
})
