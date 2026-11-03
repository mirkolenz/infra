# brcmfmac and the Broadcom Bluetooth drivers with upstream's patches for the
# chips Apple fits. They tune Wi-Fi streams, power save and resume, add the AWDL
# interface `t2-drop` uses, and fix Bluetooth LE scanning and audio dropouts
# next to 2.4 GHz Wi-Fi.
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

  version = "0.1.12-unstable-2026-11-02";

  src = kait2en.fetchSource {
    rev = "3206d9e4ea6cb49caba20f374954220555577fcc";
    hash = "sha256-s62J2+RuzRkRthdTthSe9uZ08e28gw/27aIHfPaAWug=";
    root = "patches/runtime/wireless";
  };

  # brcmfmac includes the shared headers of its parent.
  sources = [
    brcm80211
    bluetooth
  ];
  drivers = [
    "${brcm80211}/brcmfmac"
    bluetooth
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
