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

  sourceRoot = ".";

  # The asset is the bare executable, so it only needs its final name.
  unpackCmd = ''cp "$curSrc" herdr'';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Agent multiplexer that lives in your terminal";
    license = lib.licenses.asl20;
  };
}
