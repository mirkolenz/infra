# brcmfmac and the Broadcom Bluetooth drivers with upstream's patches for the
# chips Apple fits. They tune Wi-Fi streams, power save and resume, add the AWDL
# interface `t2-drop` uses, and fix Bluetooth LE scanning and audio dropouts
# next to 2.4 GHz Wi-Fi. Like upstream, brcmfmac keeps its debug messages.
# https://github.com/kaiT2en/KaiT2en-Fedora/blob/main/scripts/fedora/install-wireless.sh
{
  lib,
  kait2en,
}:
let
  brcm80211 = "drivers/net/wireless/broadcom/brcm80211";
  bluetooth = "drivers/bluetooth";

  # The patched drivers and those linking to them, as upstream's installer
  # selects them. The rest of their directories stays in-tree.
  modules = [
    "brcmutil"
    "brcmfmac"
    "brcmfmac-wcc"
    "brcmfmac-cyw"
    "brcmfmac-bca"
    "btbcm"
    "hci_uart"
    "hci_bcm4377"
  ];
in
kait2en.mkPatchedDrivers {
  pname = "kait2en-wireless";

  version = "0.1.13-unstable-2026-11-11";

  src = kait2en.fetchSource {
    rev = "9c6e22d0d5ece62351ccef78fe4bb710ab2dabaa";
    hash = "sha256-VZ28Hd4uiG2lQ8Y/hCk+Rp7c1ln/r5cK4ZFwBJr+mAw=";
    root = "patches/runtime/wireless";
    # Only tracked, so the check flags a change to what `makeFlags` mirrors.
    paths = [ "scripts/fedora/install-wireless.sh" ];
  };

  # The parent holds brcmfmac's shared headers and builds brcmutil along,
  # which exports brcmfmac's debug helpers.
  drivers = [
    brcm80211
    bluetooth
  ];

  # The parent turns `CONFIG_BRCMDBG` into `-DDEBUG` for its subdirectories,
  # the C code checks the macro, and brcmsmac is left in-tree.
  makeFlags = [
    "CONFIG_BRCMDBG=y"
    "CONFIG_BRCMSMAC="
    "KCPPFLAGS=-DCONFIG_BRCMDBG=1"
  ];

  postInstall = ''
    find $out/lib/modules -name '*.ko*' \
      ${lib.concatMapStringsSep " " (module: "! -name '${module}.ko*'") modules} -delete
  '';

  meta = {
    description = "Broadcom Wi-Fi and Bluetooth drivers tuned for Apple T2 Macs";
    # brcmfmac is ISC, the Bluetooth drivers GPL-2.0-or-later and hci_bcm4377
    # GPL-2.0-only or MIT, and the patches follow the rest of upstream.
    license = with lib.licenses; [
      isc
      gpl2Plus
      gpl2Only
      mit
      gpl3Plus
    ];
  };
}
