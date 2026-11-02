{
  lib,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  mkGitHubBinary,
  stdenv,
}:
mkGitHubBinary {
  owner = "github";
  repo = "copilot-cli";
  file = ./release.json;
  pname = "copilot-cli";
  versionPrefix = "v";
  assets = {
    x86_64-linux = "copilot-linux-x64.tar.gz";
    aarch64-linux = "copilot-linux-arm64.tar.gz";
    aarch64-darwin = "copilot-darwin-arm64.tar.gz";
  };
  binaries = [ "copilot" ];

  sourceRoot = ".";

  buildInputs = lib.optionals stdenv.hostPlatform.isElf [
    stdenv.cc.cc
  ];

  # otherwise the bun runtime is executed instead of the binary (on linux)
  dontStrip = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  doInstallCheck = true;

  strictDeps = true;

  meta = {
    description = "GitHub Copilot CLI - AI-powered command line tool";
    license = lib.licenses.unfree;
    mainProgram = "copilot";
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
}
