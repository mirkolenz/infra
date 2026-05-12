{
  lib,
  stdenvNoCC,
  versionCheckHook,
  mkGitHubBinary,
  writableTmpDirAsHomeHook,
  unzip,
  makeBinaryWrapper,
}:
mkGitHubBinary {
  owner = "anomalyco";
  repo = "opencode";
  file = ./release.json;
  assets = {
    x86_64-linux = "opencode-linux-x64.tar.gz";
    aarch64-linux = "opencode-linux-arm64.tar.gz";
    aarch64-darwin = "opencode-darwin-arm64.zip";
  };
  versionPrefix = "v";

  sourceRoot = ".";

  nativeBuildInputs = [
    unzip
    makeBinaryWrapper
    writableTmpDirAsHomeHook
  ];

  __noChroot = stdenvNoCC.isDarwin;

  # otherwise the bun runtime is executed instead of the binary (on linux)
  dontStrip = true;

  postInstall = ''
    wrapProgram $out/bin/opencode \
      --set OPENCODE_DISABLE_AUTOUPDATE 1
  '';

  # todo: only bash supported: https://github.com/anomalyco/opencode/issues/1515
  # installShellCompletionPhase = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
  #   installShellCompletion --cmd opencode \
  #     --bash <($out/bin/opencode completion)
  # '';

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  doInstallCheck = true;

  meta = {
    description = "Open source coding agent";
    license = lib.licenses.mit;
  };
}
