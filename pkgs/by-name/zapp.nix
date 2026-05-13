{
  lib,
  rustPlatform,
  pkg-config,
  udev,
  stdenv,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "zapp";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "zsa";
    repo = "zapp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-KhWL+SsN1z9qpxwHpaqRo3qAk7xAOHVkRAOa02Q2Myc=";
  };

  cargoHash = "sha256-gDyNwHrMdNQdKdr9RGfwFAU8IaUlGrlJxV0WClQ25JM=";

  passthru.updateScript = nix-update-script { };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    udev
  ];

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
