{
  lib,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  owner = "typst";
  repo = "typst";
  file = ./release.json;
  assets = {
    x86_64-linux = "typst-x86_64-unknown-linux-musl.tar.xz";
    aarch64-linux = "typst-aarch64-unknown-linux-musl.tar.xz";
    aarch64-darwin = "typst-aarch64-apple-darwin.tar.xz";
  };
  versionPrefix = "v";

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "New markup-based typesetting system that is powerful and easy to learn";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
}
