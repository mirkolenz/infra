{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
buildNpmPackage (finalAttrs: {
  pname = "scanoss-js";
  version = "0.40.2";

  src = fetchFromGitHub {
    owner = "scanoss";
    repo = "scanoss.js";
    tag = "v${finalAttrs.version}";
    hash = "sha256-OwhwE1mz4ml7XUVx9ATgSvKKcwj45pb165g5M0/VuoU=";
  };

  npmDepsHash = "sha256-lBuymitzz0mK0ehqAtqkusvtRsgEB2wWTVfCAHOr2AM=";

  # the lockfile is generated on linux, where the darwin-only fsevents is skipped, so npm refuses to
  # install from it on darwin; chokidar only needs it to watch files during development
  patches = [ ./fsevents.patch ];

  passthru.updateScript = nix-update-script { };

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "JavaScript library and CLI to leverage the SCANOSS APIs";
    homepage = "https://github.com/scanoss/scanoss.js";
    changelog = "https://github.com/scanoss/scanoss.js/blob/${finalAttrs.src.tag}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "scanoss-js";
  };
})
