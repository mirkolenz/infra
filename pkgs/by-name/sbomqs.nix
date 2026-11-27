{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "sbomqs";
  version = "2.1.4";

  src = fetchFromGitHub {
    owner = "interlynk-io";
    repo = "sbomqs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-w/4sGCPc9ItM+swvSOsqCQR75M4q9E7P57fj+NmMSvE=";
  };

  vendorHash = "sha256-3i7A5YJmTpHV4dpb66dZKoVTwmudBpmEc7wq60d34z0=";

  ldflags = [
    "-s"
    "-X=sigs.k8s.io/release-utils/version.gitVersion=v${finalAttrs.version}"
  ];

  passthru.updateScript = nix-update-script { };

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "version";
  doInstallCheck = true;

  __darwinAllowLocalNetworking = true;
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
