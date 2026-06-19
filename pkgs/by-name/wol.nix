{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  writableTmpDirAsHomeHook,
  versionCheckHook,
  installShellFiles,
  stdenv,
}:
buildGoModule (finalAttrs: {
  pname = "wol";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "Trugamr";
    repo = "wol";
    tag = "v${finalAttrs.version}";
    hash = "sha256-PKAijKeTZnfa65aS+qZcUYcMdLGve772lWTBuUPmL1Q=";
  };

  vendorHash = "sha256-MZBB9TIiVEUb6OyYReIpsrEPd3yruj3LSc5eR5qYHho=";

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-X=github.com/trugamr/wol/cmd.version=${finalAttrs.version}"
    "-X=github.com/trugamr/wol/cmd.commit=${finalAttrs.src.rev}"
    "-X=github.com/trugamr/wol/cmd.date=1970-01-01T00:00:00Z"
  ];

  nativeBuildInputs = [ installShellFiles ];

  postFixup = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd wol \
      --bash <($out/bin/wol completion bash) \
      --fish <($out/bin/wol completion fish) \
      --zsh <($out/bin/wol completion zsh)
  '';

  passthru.updateScript = nix-update-script { };

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "version";
  doInstallCheck = true;

  strictDeps = true;
  __structuredAttrs = true;

  meta = {
    description = "Wake up your devices with a single command or click, a Wake-On-LAN tool that works via CLI and web interface";
    homepage = "https://github.com/Trugamr/wol";
    changelog = "https://github.com/Trugamr/wol/releases";
    downloadPage = "https://github.com/Trugamr/wol/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "wol";
  };
})
