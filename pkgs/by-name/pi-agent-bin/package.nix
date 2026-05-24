{
  lib,
  versionCheckHook,
  mkGitHubBinary,
  makeBinaryWrapper,
  stdenv,
}:
mkGitHubBinary {
  owner = "badlogic";
  repo = "pi-mono";
  pname = "pi";
  file = ./release.json;
  assets = {
    x86_64-linux = "pi-linux-x64.tar.gz";
    aarch64-linux = "pi-linux-arm64.tar.gz";
    aarch64-darwin = "pi-darwin-arm64.tar.gz";
  };
  versionPrefix = "v";
  binaries = [ ];

  buildInputs = lib.optionals stdenv.hostPlatform.isElf [ stdenv.cc.cc ];
  nativeBuildInputs = [ makeBinaryWrapper ];

  # strip is not compatible with the bun runtime
  dontStrip = true;

  postInstall = ''
    mkdir -p $out/bin
    cp -r . $out/libexec
    makeBinaryWrapper $out/libexec/pi $out/bin/pi
  '';

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  doInstallCheck = true;

  meta = {
    description = "AI-powered coding assistant";
    license = lib.licenses.mit;
  };
}
