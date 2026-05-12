{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  nix-update-script,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
buildGoModule (finalAttrs: {
  pname = "gibo";
  version = "3.0.22";

  src = fetchFromGitHub {
    owner = "simonwhitaker";
    repo = "gibo";
    tag = "v${finalAttrs.version}";
    hash = "sha256-oI/+bsYI7AgIbJ/FwhMrzAXqq7e45tTO6EueVXI3/+I=";
  };

  vendorHash = "sha256-/geO0XxT53Cw/s2TlvxkLfR/w8c724Z4UMrpTPcEDFM=";

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-X=github.com/simonwhitaker/gibo/cmd.version=${finalAttrs.version}"
  ];

  nativeBuildInputs = [ installShellFiles ];

  postFixup = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd gibo \
      --bash <($out/bin/gibo completion bash) \
      --fish <($out/bin/gibo completion fish) \
      --zsh <($out/bin/gibo completion zsh)
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
    description = "Easy access to gitignore boilerplates";
    homepage = "https://github.com/simonwhitaker/gibo";
    downloadPage = "https://github.com/simonwhitaker/gibo/releases";
    license = lib.licenses.unlicense;
    maintainers = with lib.maintainers; [ mirkolenz ];
    mainProgram = "gibo";
  };
})
