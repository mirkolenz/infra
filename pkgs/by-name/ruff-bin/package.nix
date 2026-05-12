{
  lib,
  stdenv,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  owner = "astral-sh";
  repo = "ruff";
  file = ./release.json;
  assets = {
    x86_64-linux = "ruff-x86_64-unknown-linux-gnu.tar.gz";
    aarch64-linux = "ruff-aarch64-unknown-linux-gnu.tar.gz";
    aarch64-darwin = "ruff-aarch64-apple-darwin.tar.gz";
  };

  buildInputs = lib.optionals stdenv.hostPlatform.isElf [ stdenv.cc.cc ];

  postFixup = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd ruff \
      --bash <($out/bin/ruff generate-shell-completion bash) \
      --fish <($out/bin/ruff generate-shell-completion fish) \
      --zsh <($out/bin/ruff generate-shell-completion zsh)
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Extremely fast Python linter and code formatter, written in Rust";
    license = lib.licenses.mit;
  };
}
