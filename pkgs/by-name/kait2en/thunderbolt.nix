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

  version = "0.1.16-unstable-2026-11-23";

  src = kait2en.fetchSource {
    rev = "6915384500c59c7ac4842977a40b4269f122bdbc";
    hash = "sha256-jwYzNtyP03nXKEr+fVeAL9ZmOyoYVie2x+kmHGybxLw=";
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
