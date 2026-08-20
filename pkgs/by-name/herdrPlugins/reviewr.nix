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
  version = "0.33.0";
  pluginId = "persiyanov.reviewr";

  src = fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kS40fu57daPBUzUzEojOz2LrGzo90sYpeL3VCZK88X0=";
  };

  binary = rustPlatform.buildRustPackage {
    inherit (finalAttrs) pname version src;
    cargoHash = "sha256-043nvKhAbASHRVL0/R+DVvZPC4dAv3J+XAnH7HD8b6Q=";
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
