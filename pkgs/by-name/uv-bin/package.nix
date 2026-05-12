{
  lib,
  stdenv,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  owner = "astral-sh";
  repo = "uv";
  file = ./release.json;
  assets = {
    x86_64-linux = "uv-x86_64-unknown-linux-gnu.tar.gz";
    aarch64-linux = "uv-aarch64-unknown-linux-gnu.tar.gz";
    aarch64-darwin = "uv-aarch64-apple-darwin.tar.gz";
  };
  binaries = [
    "uv"
    "uvx"
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isElf [ stdenv.cc.cc ];

  installShellCompletionPhase = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd uv \
      --bash <($out/bin/uv generate-shell-completion bash) \
      --fish <($out/bin/uv generate-shell-completion fish) \
      --zsh <($out/bin/uv generate-shell-completion zsh)
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Extremely fast Python package and project manager, written in Rust";
    license = with lib.licenses; [
      mit
      asl20
    ];
  };
}
