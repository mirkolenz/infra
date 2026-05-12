{
  lib,
  stdenv,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  owner = "astral-sh";
  repo = "ty";
  file = ./release.json;
  assets = {
    x86_64-linux = "ty-x86_64-unknown-linux-gnu.tar.gz";
    aarch64-linux = "ty-aarch64-unknown-linux-gnu.tar.gz";
    aarch64-darwin = "ty-aarch64-apple-darwin.tar.gz";
  };
  allowPrereleases = true;

  buildInputs = lib.optionals stdenv.hostPlatform.isElf [ stdenv.cc.cc ];

  postFixup = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd ty \
      --bash <($out/bin/ty generate-shell-completion bash) \
      --fish <($out/bin/ty generate-shell-completion fish) \
      --zsh <($out/bin/ty generate-shell-completion zsh)
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Extremely fast Python type checker and language server, written in Rust";
    license = lib.licenses.mit;
  };
}
