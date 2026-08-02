{
  lib,
  mkHerdrPlugin,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  bat,
  delta,
  git,
  glow,
}:
mkHerdrPlugin (finalAttrs: {
  pname = "herdr-file-viewer";
  version = "1.14.0";
  pluginId = "herdr-file-viewer";

  src = fetchFromGitHub {
    owner = "smarzban";
    repo = "herdr-file-viewer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-QJM/w1m7j8B433/klHRCRbJKL51/5tkyp7swm0xG3zE=";
  };

  binary = rustPlatform.buildRustPackage {
    inherit (finalAttrs) pname version src;
    cargoHash = "sha256-ZzGvgemjSKUBFr1I6tzgtKopNVQyOsregU51PrV3/rY=";
    # the integration tests drive a pty and expect a herdr server
    cargoTestFlags = [ "--lib" ];
    nativeCheckInputs = [ git ];
    # the viewer looks for its glow style next to the executable, so it has to
    # ship with the binary rather than in the plugin root the wrapper hides
    postInstall = ''
      install -Dm644 assets/markdown-style.json "$out/assets/markdown-style.json"
    '';
    meta.mainProgram = "herdr-file-viewer";
  };
  binaryPath = "target/release/herdr-file-viewer";
  entrypoints = [
    "scripts/open-file-viewer.sh"
    "scripts/open-file-viewer-tab.sh"
  ];

  # the content pane renders through these when they are on PATH
  runtimeInputs = [
    bat
    delta
    git
    glow
  ];
  # the version is pinned in-tree, so the viewer's own release check is noise
  extraWrapperArgs = [
    "--set"
    "HERDR_FILE_VIEWER_NO_UPDATE_CHECK"
    "1"
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--subpackage"
      "binary"
    ];
  };

  meta = {
    description = "Git-aware, read-only file viewer for herdr";
    homepage = "https://github.com/smarzban/herdr-file-viewer";
    license = lib.licenses.mit;
  };
})
