# brcmfmac and the Broadcom Bluetooth drivers with upstream's patches for the
# chips Apple fits: two spatial streams instead of one beamformed on the
# BCM4364, a 200 ms power save timeout, no P2P from the firmware's "hp2p"
# capability, the AP 4-way handshake left to the host, and a raised ACL
# priority against audio dropouts while Wi-Fi runs on 2.4 GHz.
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

  series = "wireless";

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
