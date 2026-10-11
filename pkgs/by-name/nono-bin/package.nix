{
  lib,
  stdenv,
  versionCheckHook,
  mkGitHubBinary,
}:
mkGitHubBinary {
  owner = "nolabs-ai";
  repo = "nono";
  file = ./release.json;
  assets =
    version:
    lib.mapAttrs (_: target: "nono-v${version}-${target}.tar.gz") {
      x86_64-linux = "x86_64-unknown-linux-gnu";
      aarch64-linux = "aarch64-unknown-linux-gnu";
      aarch64-darwin = "aarch64-apple-darwin";
    };
  versionPrefix = "v";

  sourceRoot = ".";

  buildInputs = lib.optionals stdenv.hostPlatform.isElf [ stdenv.cc.cc.lib ];

  # The darwin binary carries a Developer ID signature that stripping would break.
  dontFixup = stdenv.hostPlatform.isDarwin;

  installShellCompletionPhase = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd nono \
      --bash <($out/bin/nono completion bash) \
      --fish <($out/bin/nono completion fish) \
      --zsh <($out/bin/nono completion zsh)
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Capability-based sandbox for AI agents";
    license = lib.licenses.asl20;
  };
}
