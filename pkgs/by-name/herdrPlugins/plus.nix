{
  lib,
  mkHerdrPlugin,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  gitMinimal,
}:
mkHerdrPlugin (finalAttrs: {
  pname = "herdr-plus";
  version = "0.1.23";
  pluginId = "cloudmanic.herdr-plus";

  src = fetchFromGitHub {
    owner = "cloudmanic";
    repo = "herdr-plus";
    tag = "v${finalAttrs.version}";
    hash = "sha256-QGmJAU0dTEd58/CEJZohMBM9ibLYbQL4mh0gg4VSJSY=";
  };

  binary = buildGoModule {
    inherit (finalAttrs) pname version src;
    vendorHash = "sha256-im2gPhLarMf1w/8rhxbOe9EhUdvseffukT9tqU4EEXI=";
    subPackages = [ "." ];
    nativeCheckInputs = [ gitMinimal ];
    meta.mainProgram = "herdr-plus";
  };
  # every action, pane, and event runs the binary directly, so there is no script
  # entry point to wrap
  binaryPath = "bin/herdr-plus";

  runtimeInputs = [ gitMinimal ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--subpackage"
      "binary"
    ];
  };

  meta = {
    description = "Projects and quick actions for herdr";
    homepage = "https://github.com/cloudmanic/herdr-plus";
    license = lib.licenses.mit;
  };
})
