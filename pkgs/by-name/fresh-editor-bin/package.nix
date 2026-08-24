{
  lib,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  owner = "sinelaw";
  repo = "fresh";
  file = ./release.json;
  assets = {
    x86_64-linux = "fresh-editor-x86_64-unknown-linux-musl.tar.xz";
    aarch64-linux = "fresh-editor-aarch64-unknown-linux-musl.tar.xz";
    aarch64-darwin = "fresh-editor-aarch64-apple-darwin.tar.xz";
  };
  versionPrefix = "v";

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Terminal based IDE and text editor that is easy, powerful, and fast";
    license = lib.licenses.gpl2Only;
  };
}
