{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "osv-scalibr";
  version = "0.5.4";

  src = fetchFromGitHub {
    owner = "google";
    repo = "osv-scalibr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-sTTR9l+cG5Q+8MM2MLvxMPneewKwTSxzsfQeZD6+44c=";
  };

  vendorHash = "sha256-db0sZiQQtHm1AT0cLIjcepv+mlNWT8mFafplIszoJcQ=";

  subPackages = [ "binary/scalibr" ];

  passthru.updateScript = nix-update-script { };

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "-version";
  doInstallCheck = true;

  __structuredAttrs = true;

  meta = {
    description = "Software composition analysis scanning an image, filesystem or container for installed packages and vulnerabilities";
    homepage = "https://github.com/google/osv-scalibr";
    changelog = "https://github.com/google/osv-scalibr/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "scalibr";
  };
})
