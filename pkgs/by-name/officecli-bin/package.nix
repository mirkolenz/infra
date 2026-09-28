{
  lib,
  versionCheckHook,
  mkGitHubBinary,
  stdenv,
  icu,
}:
mkGitHubBinary {
  owner = "iOfficeAI";
  repo = "OfficeCLI";
  pname = "officecli";
  file = ./release.json;
  assets = {
    x86_64-linux = "officecli-linux-x64";
    aarch64-linux = "officecli-linux-arm64";
    aarch64-darwin = "officecli-mac-arm64";
  };
  versionPrefix = "v";

  sourceRoot = ".";

  # The asset is the bare executable, so it only needs its final name.
  unpackCmd = ''cp "$curSrc" officecli'';

  # strip corrupts the embedded .NET single-file bundle
  dontStrip = true;

  buildInputs = lib.optionals stdenv.hostPlatform.isElf [ stdenv.cc.cc.lib ];
  # .NET loads ICU via dlopen, so autoPatchelfHook cannot detect it.
  runtimeDependencies = lib.optionals stdenv.hostPlatform.isElf [ icu ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Office suite for AI agents to read, edit, and automate Word, Excel, and PowerPoint files";
    license = lib.licenses.asl20;
  };
}
