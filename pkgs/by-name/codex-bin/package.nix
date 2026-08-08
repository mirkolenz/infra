{
  lib,
  stdenv,
  versionCheckHook,
  mkGitHubBinary,
}:
let
  platforms = {
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-linux = "aarch64-unknown-linux-musl";
    aarch64-darwin = "aarch64-apple-darwin";
  };
  platform = platforms.${stdenv.hostPlatform.system};
  # codex discovers its helpers next to its own executable, so they all live in $out/bin.
  programs = [
    "codex"
    "codex-app-server"
    "codex-code-mode-host"
    "codex-responses-api-proxy"
  ];
in
mkGitHubBinary {
  owner = "openai";
  repo = "codex";
  file = ./release.json;
  assets = lib.mapAttrs (_: plat: map (bin: "${bin}-${plat}.tar.gz") programs) platforms;
  versionPrefix = "rust-v";
  # Each tarball holds a single platform-suffixed executable.
  binaries = lib.genAttrs programs (bin: "${bin}-${platform}");

  sourceRoot = ".";

  installShellCompletionPhase = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    license = lib.licenses.asl20;
  };
}
