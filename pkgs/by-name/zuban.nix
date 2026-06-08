{
  lib,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
  python3,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "zuban";
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "zubanls";
    repo = "zuban";
    rev = "v${finalAttrs.version}";
    hash = "sha256-+l1aAnYIZHHYEm1fX5QXYmbMxMLOHlGEQI0khMZEU+E=";
    fetchSubmodules = true;
  };

  buildAndTestSubdir = "crates/zuban";

  cargoHash = "sha256-xRM8uaryE21CPB6M6qBfW01GitrPt0KVRIhDX+80fpY=";

  postInstall = ''
    mkdir -p $out/${python3.sitePackages}/zuban
    cp -r third_party $out/${python3.sitePackages}/zuban/
  '';

  passthru.updateScript = nix-update-script { };

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "Python Type Checker / Language Server";
    homepage = "https://github.com/zubanls/zuban";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "zuban";
  };
})
