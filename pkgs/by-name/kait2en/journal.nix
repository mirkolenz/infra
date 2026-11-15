# Merges the T2's bridgeOS logs into a Linux boot's journal, the only way to see
# what the T2 did across a suspend or a watchdog reset.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/t2-journal
{
  lib,
  kait2en,
}:
kait2en.mkService {
  version = "0.1.14-unstable-2026-11-15";

  src = kait2en.fetchSource {
    rev = "260a559597a7bd3b168a9a251a2248d97aadd957";
    hash = "sha256-DCWuEdWRADcxvLlcfn5bF4A1Kdo4C2o7G4dMdIXDC5I=";
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
