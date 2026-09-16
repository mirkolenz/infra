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
  version = "0.38.0";
  pluginId = "persiyanov.reviewr";

  src = fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-nHQlbENR4NQBKz2GTkYQqhr0JuulqFYSi7CjiIY9IhY=";
  };

  binary = rustPlatform.buildRustPackage {
    inherit (finalAttrs) pname version src;
    cargoHash = "sha256-OYL8Hm7yrFYbhLatyXV2d64/8TxL/BqCHdCdaMu1ckw=";
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
    changelog = "https://github.com/persiyanov/herdr-reviewr/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
  };
})
