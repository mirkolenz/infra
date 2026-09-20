{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
# go.mod requires a newer toolchain than the nixpkgs default
buildGo127Module (finalAttrs: {
  pname = "sbomqs";
  version = "2.1.2";

  src = fetchFromGitHub {
    owner = "interlynk-io";
    repo = "sbomqs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-S0CcvnvbtHzN7vm5TF8vm0uGEklTjeqcJFcF7/H6l3M=";
  };

  vendorHash = "sha256-EK/2keML/TlKLTppwSKZtkQNfrL/PE+hGKMFSjYDRew=";

  ldflags = [
    "-s"
    "-X=sigs.k8s.io/release-utils/version.gitVersion=v${finalAttrs.version}"
  ];

  passthru.updateScript = nix-update-script { };

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "version";
  doInstallCheck = true;

  __structuredAttrs = true;

  meta = {
    description = "Quality and compliance scoring for SBOMs, including the BSI TR-03183-2 and NTIA minimum element profiles";
    homepage = "https://github.com/interlynk-io/sbomqs";
    changelog = "https://github.com/interlynk-io/sbomqs/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "sbomqs";
  };
})
