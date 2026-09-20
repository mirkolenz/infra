{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "osv-scalibr";
  version = "0.5.2";

  src = fetchFromGitHub {
    owner = "google";
    repo = "osv-scalibr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-J/KbFDlVfnPpqy1jQrKqizOlBmsXYLD3rKUKg/D6ofE=";
  };

  vendorHash = "sha256-ZxVnh509Oy3buK49Juvmu2+LjYiW8G/UhXYVJ2rh5Jo=";

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
