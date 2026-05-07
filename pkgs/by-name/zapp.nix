{
  lib,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "zapp";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "zsa";
    repo = "zapp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-0gf1famCPfsShYyankk9/Y/aA8/XbCbOJVmdNl416jk=";
  };

  cargoHash = "sha256-0jmYOfuAfmq8vJvWww6WHjt1J5nRbDDFNFi/vN5ANk8=";

  passthru.updateScript = nix-update-script { };

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "Flash ZSA keyboards from your terminal";
    homepage = "https://github.com/zsa/zapp";
    license = with lib.licenses; [
      mit
      commons-clause
    ];
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "zapp";
  };
})
