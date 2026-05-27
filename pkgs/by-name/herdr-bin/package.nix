{
  lib,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  owner = "ogulcancelik";
  repo = "herdr";
  file = ./release.json;
  assets = {
    x86_64-linux = "herdr-linux-x86_64";
    aarch64-linux = "herdr-linux-aarch64";
    aarch64-darwin = "herdr-macos-aarch64";
  };
  versionPrefix = "v";

  dontUnpack = true;

  preInstall = ''
    cp $src herdr
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Agent multiplexer that lives in your terminal";
    license = lib.licenses.agpl3Only;
  };
}
