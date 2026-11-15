{
  lib,
  mkHerdrPlugin,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  gitMinimal,
  pkg-config,
  oniguruma,
  libgit2,
}:
mkHerdrPlugin (finalAttrs: {
  pname = "herdr-reviewr";
  version = "0.52.2";
  pluginId = "persiyanov.reviewr";

  src = fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DcNNuP529AhERUhnM0qHNYZuqlCghmc+psiKrX4l+gw=";
  };

  binary = rustPlatform.buildRustPackage {
    inherit (finalAttrs) pname version src;
    cargoHash = "sha256-lPIvi3ImQ606lADDF0CPpjVGs8uU2neL/C4usUG2QW8=";
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [
      oniguruma
      libgit2
    ];
    # the integration tests run the plugin entry points against a git checkout
    cargoTestFlags = [ "--lib" ];
    nativeCheckInputs = [ gitMinimal ];
    meta.mainProgram = "herdr-reviewr";
  };
  binaryPath = "bin/herdr-reviewr";

  runtimeInputs = [ gitMinimal ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Code review sidebar for herdr that sends line comments back to the agent";
    homepage = "https://github.com/persiyanov/herdr-reviewr";
    changelog = "https://github.com/persiyanov/herdr-reviewr/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
})
