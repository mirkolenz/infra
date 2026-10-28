{
  lib,
  stdenv,
  fetchFromGitHub,
  swift,
  swiftpm,
  fetchSwiftPMDeps,
  installShellFiles,
  versionCheckHook,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "utiluti";
  version = "1.5";

  src = fetchFromGitHub {
    owner = "scriptingosx";
    repo = "utiluti";
    tag = "v${finalAttrs.version}";
    hash = "sha256-p71flMX9ENtyges/zQqTENteTFVHsKJjyOnohFZitpA=";
  };

  # skip unchanged defaults in `manage`, since macOS 26.4 prompts for every change
  patches = [ ./manage-skip-unchanged.patch ];

  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-CndH6UnHSiQUB+gLxGvGkS685ZoeSkv4xgjNGQQ5K98=";
  };

  nativeBuildInputs = [
    swift
    swiftpm
    installShellFiles
  ];

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd utiluti \
      --bash <($out/bin/utiluti --generate-completion-script bash) \
      --fish <($out/bin/utiluti --generate-completion-script fish) \
      --zsh <($out/bin/utiluti --generate-completion-script zsh)
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru.updateScript = nix-update-script { };

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "macOS command line utility to work with default apps";
    homepage = "https://github.com/scriptingosx/utiluti";
    changelog = "https://github.com/scriptingosx/utiluti/blob/${finalAttrs.src.tag}/ChangeLog.md";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "utiluti";
    platforms = lib.platforms.darwin;
  };
})
