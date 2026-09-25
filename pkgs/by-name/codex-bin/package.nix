{
  lib,
  stdenv,
  versionCheckHook,
  mkGitHubBinary,
  ripgrep,
  bubblewrap,
  ncurses,
}:
mkGitHubBinary {
  owner = "openai";
  repo = "codex";
  file = ./release.json;
  assets = lib.mapAttrs (_: plat: "codex-package-${plat}.tar.gz") {
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-linux = "aarch64-unknown-linux-musl";
    aarch64-darwin = "aarch64-apple-darwin";
  };
  versionPrefix = "rust-v";

  # The tarball has no top-level directory, extract it straight into place.
  dontUnpack = true;

  # The voice runtime pins its bundled libraries in runtime.json.
  dontStrip = true;

  # The vendored zsh links against libtinfo.
  buildInputs = lib.optionals stdenv.hostPlatform.isElf [ ncurses ];

  # codex detects its package layout via codex-package.json next to bin/,
  # so keep the tree intact and symlink rather than wrap the entrypoint.
  # Stock tools replace their vendored copies, the zsh fork and voice runtime stay.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/codex
    tar -xf "$srcs" -C $out/libexec/codex
    ln -s $out/libexec/codex/bin/codex $out/bin/codex
    ln -sf ${lib.getExe ripgrep} $out/libexec/codex/codex-path/rg
    ${lib.optionalString stdenv.hostPlatform.isLinux "ln -sf ${lib.getExe bubblewrap} $out/libexec/codex/codex-resources/bwrap"}

    runHook postInstall
  '';

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
