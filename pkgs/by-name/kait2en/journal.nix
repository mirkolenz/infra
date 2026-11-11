# Merges the T2's bridgeOS logs into a Linux boot's journal, the only way to see
# what the T2 did across a suspend or a watchdog reset.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/t2-journal
{
  lib,
  kait2en,
}:
kait2en.mkService {
  version = "0.1.13-unstable-2026-11-11";

  src = kait2en.fetchSource {
    rev = "9c6e22d0d5ece62351ccef78fe4bb710ab2dabaa";
    hash = "sha256-ZDvSLKb3IAybDvCDPH/z4i2wFpLIq9UXScitXnY8Kbc=";
    root = "t2-services/t2-journal";
    bridgexpc = true;
  };

  cargoHash = "sha256-xNXdWkmrG+63VWCLbWyE6T1p21nSiyPx7DDhsfQGF5I=";

  # The vendored log parser is the one part of the tree that is not GPL.
  postInstall = ''
    install -Dm444 $cargoRoot/libs/macos-unifiedlogs/LICENSE \
      $out/share/licenses/kait2en-journal/LICENSE.macos-unifiedlogs
  '';

  meta = {
    description = "Merge Apple T2 bridgeOS logs with the Linux journal";
    mainProgram = "t2journal";
    license = with lib.licenses; [
      gpl3Plus
      asl20
    ];
  };
}
