{
  lib,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  pname = "jscpd";
  owner = "kucherenko";
  repo = "jscpd";
  file = ./release.json;
  assets = {
    x86_64-linux = "jscpd-linux-x64-gnu.tar.gz";
    aarch64-linux = "jscpd-linux-arm64-gnu.tar.gz";
    aarch64-darwin = "jscpd-darwin-arm64.tar.gz";
  };
  versionPrefix = "v";

  sourceRoot = ".";

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Copy-paste detector covering 220 languages, with a Rust engine";
    license = lib.licenses.mit;
  };
}
