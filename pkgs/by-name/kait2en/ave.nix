# Userspace half of the T2's audio/video engine: `kait2en.modules` exposes the
# device, this daemon opens the sessions and ships the sleep hook closing them.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/t2-ave
{
  lib,
  kait2en,
  makeWrapper,
  runtimeShell,
  coreutils,
}:
kait2en.mkService {
  component = "ave";

  cargoHash = "sha256-aVKFnhAI52Am2LZNyJJN1Es06dvvN7a3FpcjUtfUPfE=";

  nativeBuildInputs = [ makeWrapper ];

  # The hook needs `t2remote` and `timeout` on a PATH sleep does not provide.
  postInstall = ''
    install -Dm555 t2-services/t2-ave/integration/systemd/t2-ave-suspend \
      $out/libexec/kait2en/sleep.d/t2-ave
    substituteInPlace $out/libexec/kait2en/sleep.d/t2-ave \
      --replace-fail '#!/usr/bin/env bash' '#!${runtimeShell}'
    wrapProgram $out/libexec/kait2en/sleep.d/t2-ave \
      --prefix PATH : ${lib.makeBinPath [ coreutils ]}:$out/bin
  '';

  meta = {
    description = "Apple T2 AVE service daemon";
    mainProgram = "t2remote";
  };
}
