# thunderbolt with upstream's runtime PM for the Titan Ridge and Ice Lake
# controllers of T2 Macs, which lets the idle controller power down so the
# package reaches its deep idle states. It only acts on Apple machines.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/scripts/fedora/install-thunderbolt.sh
{
  lib,
  kait2en,
}:
kait2en.mkPatchedDrivers {
  pname = "kait2en-thunderbolt";

  version = "0.1.13-unstable-2026-11-11";

  src = kait2en.fetchSource {
    rev = "9c6e22d0d5ece62351ccef78fe4bb710ab2dabaa";
    hash = "sha256-YLnQUNVKb9rl8MJURFYVRFW4HSxG5U5PN8D3sDOAUC8=";
    root = "patches/runtime/thunderbolt";
    # Only tracked, so the check flags a change to what is built.
    paths = [ "scripts/fedora/install-thunderbolt.sh" ];
  };

  drivers = [ "drivers/thunderbolt" ];

  # Like upstream, the other modules of the directory stay in-tree.
  makeFlags = [
    "CONFIG_USB4_DMA_TEST="
    "CONFIG_USB4_STREAM="
  ];

  meta = {
    description = "Thunderbolt driver with runtime power management for Apple T2 Macs";
    # The driver is GPL-2.0-only, and the patches follow the rest of upstream.
    license = with lib.licenses; [
      gpl2Only
      gpl3Plus
    ];
  };
}
