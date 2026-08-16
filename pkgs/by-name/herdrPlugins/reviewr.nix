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
  version = "0.31.0";
  pluginId = "persiyanov.reviewr";

  src = fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-iiTK8j7+mdQ3tWU9Ra96jAGGYwR3D6dZRewG9BO2EWY=";
  };

  binary = rustPlatform.buildRustPackage {
    inherit (finalAttrs) pname version src;
    cargoHash = "sha256-sR9JaKPfJFxabsLz354wQr0/duWtKeu+eXRyK83xM0o=";
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
