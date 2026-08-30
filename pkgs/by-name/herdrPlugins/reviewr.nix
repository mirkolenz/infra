{
  lib,
  mkHerdrPlugin,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  bashNonInteractive,
  gitMinimal,
  jq,
}:
mkHerdrPlugin (finalAttrs: {
  pname = "herdr-reviewr";
  version = "0.36.2";
  pluginId = "persiyanov.reviewr";

  src = fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-bQiIj9HpkwCtoR5SoyDah0w/f15fUVtSqxMZ3zxLOy8=";
  };

  binary = rustPlatform.buildRustPackage {
    inherit (finalAttrs) pname version src;
    cargoHash = "sha256-UAqKwl9xYAAF9J8g+tP4WqkOgvEhNJut7vjO2R4Fehc=";
    # the integration tests run the plugin entry points against a git checkout
    cargoTestFlags = [ "--lib" ];
    nativeCheckInputs = [ gitMinimal ];
    meta.mainProgram = "herdr-reviewr";
  };
  binaryPath = "bin/herdr-reviewr";
  interpreters = [ bashNonInteractive ];
  pluginFiles = [ "herdr/pane.sh" ];

  runtimeInputs = [
    gitMinimal
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
