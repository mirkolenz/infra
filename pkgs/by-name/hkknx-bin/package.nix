{
  lib,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  owner = "brutella";
  repo = "hkknx-public";
  pname = "hkknx";
  file = ./release.json;
  assets = version: {
    x86_64-linux = "hkknx-${version}_linux_amd64.tar.gz";
    aarch64-linux = "hkknx-${version}_linux_arm64.tar.gz";
    aarch64-darwin = "hkknx-${version}_darwin_arm64.tar.gz";
  };

  sourceRoot = ".";

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "HomeKit Bridge for KNX";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ mirkolenz ];
  };
}
