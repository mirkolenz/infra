{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
# go.mod requires a newer toolchain than the nixpkgs default
buildGo127Module (finalAttrs: {
  pname = "sbomasm";
  version = "2.1.2";

  src = fetchFromGitHub {
    owner = "interlynk-io";
    repo = "sbomasm";
    tag = "v${finalAttrs.version}";
    hash = "sha256-OKT7vXzHIKo1ZIbGknRL3HnDMI1RyweZmFx0U+25liU=";
  };

  vendorHash = "sha256-Dx6DJSNj7R9GP/1n0dz7JZbPVKwq8zfQQAS37aFUv/Q=";

  ldflags = [
    "-s"
    "-X=sigs.k8s.io/release-utils/version.gitVersion=v${finalAttrs.version}"
  ];

  # sbomasm stamps `sbomasm-<gitVersion>` into every document it edits, so the e2e golden
  # file asserts the unstamped `sbomasm-devel`. Teach the fixture the real version rather
  # than skipping the test, which would drop coverage of the whole `edit` command
  postPatch = ''
    substituteInPlace e2e/testdata/edit/expected-output-lite.spdx.json \
      --replace-fail "sbomasm-devel" "sbomasm-v${finalAttrs.version}"
  '';

  passthru.updateScript = nix-update-script { };

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "version";
  doInstallCheck = true;

  __structuredAttrs = true;

  meta = {
    description = "Assemble, edit and enrich SBOMs, merging several documents into one product bill of materials";
    homepage = "https://github.com/interlynk-io/sbomasm";
    changelog = "https://github.com/interlynk-io/sbomasm/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "sbomasm";
  };
})
