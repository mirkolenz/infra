{
  lib,
  mkHerdrPlugin,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  git,
  jq,
}:
mkHerdrPlugin (finalAttrs: {
  pname = "herdr-reviewr";
  version = "0.34.0";
  pluginId = "persiyanov.reviewr";

  src = fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3XUuQx8ukZ603jnwSRetRvLFtVd5ZQjlqyUFDSh8H1o=";
  };

  binary = rustPlatform.buildRustPackage {
    inherit (finalAttrs) pname version src;
    cargoHash = "sha256-9+CdHRKt1h5H062CrPLCRTp4fke0TTvaMAgMMmSaX8k=";
    # the integration tests run the plugin entry points against a git checkout
    cargoTestFlags = [ "--lib" ];
    nativeCheckInputs = [ git ];
    meta.mainProgram = "herdr-reviewr";
  };
  binaryPath = "bin/herdr-reviewr";
  entrypoints = [ "herdr/pane.sh" ];

  runtimeInputs = [
    git
    jq
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--subpackage"
      "binary"
    ];
  };

  meta = {
    description = "Code review sidebar for herdr that sends line comments back to the agent";
    homepage = "https://github.com/persiyanov/herdr-reviewr";
    license = lib.licenses.mit;
  };
})
