{
  lib,
  stdenvNoCC,
  versionCheckHook,
  mkGitHubBinary,
  writableTmpDirAsHomeHook,
  unzip,
  makeBinaryWrapper,
  fzf,
  ripgrep,
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
      --set OPENCODE_DISABLE_AUTOUPDATE 1 \
      --prefix PATH : ${
        lib.makeBinPath [
          fzf
          ripgrep
        ]
      }
  '';

  # opencode creates $TMPDIR/opencode on startup, which collides with the
  # unpacked binary of the same name in the build dir (TMPDIR == NIX_BUILD_TOP),
  # so give it an isolated TMPDIR to generate completions in.
  installShellCompletionPhase = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    TMPDIR=$(mktemp -d)
    installShellCompletion --cmd opencode \
      --bash <($out/bin/opencode completion)
  '';

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
