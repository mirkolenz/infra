{
  lib,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  owner = "github";
  repo = "gh-actions-lock";
  file = ./release.json;
  assets = {
    x86_64-linux = "linux-amd64";
    aarch64-linux = "linux-arm64";
    aarch64-darwin = "darwin-arm64";
  };
  versionPrefix = "v";

  bareExecutable = true;

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "gh extension that pins the actions of GitHub workflows in a lockfile";
    license = lib.licenses.mit;
  };
}
