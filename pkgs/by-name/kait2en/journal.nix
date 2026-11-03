# Merges the T2's bridgeOS logs into a Linux boot's journal, the only way to see
# what the T2 did across a suspend or a watchdog reset.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/t2-journal
{
  lib,
  kait2en,
}:
kait2en.mkService {
  version = "0.1.12-unstable-2026-11-02";

  src = kait2en.fetchSource {
    rev = "3206d9e4ea6cb49caba20f374954220555577fcc";
    hash = "sha256-EJA9Bp21BXBwudjOD1aaCrb+90zMTvFu1raEdZWrNao=";
    root = "t2-services/t2-journal";
    bridgexpc = true;
  };

  cargoHash = "sha256-ojuhTG4MIPtmk7RiwvzeVdHP+veS2ojz1Fslz2sPWtw=";

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
