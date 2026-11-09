{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
# grpc 1.81 references `http2.TrailerPrefix`, which x/net 0.54 drops under Go 1.27.
# Drop the pin once a release past 0.5.3 bumps grpc, as its main branch did.
buildGo126Module (finalAttrs: {
  pname = "osv-scalibr";
  version = "0.5.3";

  src = fetchFromGitHub {
    owner = "google";
    repo = "osv-scalibr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-r4nLxxwQqIy+CA8tQXxetKO8Ckqz5JVPtQyysYcVMR0=";
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
