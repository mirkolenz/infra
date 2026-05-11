{
  lib,
  stdenv,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  owner = "facebook";
  repo = "pyrefly";
  file = ./release.json;
  assets = {
    aarch64-darwin = "pyrefly-macos-arm64.tar.gz";
    aarch64-linux = "pyrefly-linux-arm64.tar.gz";
    x86_64-linux = "pyrefly-linux-x86_64.tar.gz";
  };

  buildInputs = [ stdenv.cc.cc ];

  sourceRoot = ".";

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Fast type checker and language server for Python";
    license = lib.licenses.mit;
  };
}
