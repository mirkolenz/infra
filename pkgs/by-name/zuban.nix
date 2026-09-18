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
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "zubanls";
    repo = "zuban";
    tag = "v${finalAttrs.version}";
    hash = "sha256-EA5JnuK+NxHBhbTdwUlOhYYbhXKnCEDxCn7fVEbN3JQ=";
    fetchSubmodules = true;
  };

  buildAndTestSubdir = "crates/zuban";

  cargoHash = "sha256-5zd9ve8HL2+ZE5aw1W7MeEwJfbOfXWF9wFdLOD3X2vs=";

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
    changelog = "https://github.com/zubanls/zuban/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "zuban";
  };
})
