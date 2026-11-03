# AirDrop over AWDL, which the Apple firmware runs once the patched brcmfmac of
# `kait2en.wireless` creates its interface. A root daemon on D-Bus activation
# that `kait2en.airshare` talks to.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-drop
{
  kait2en,
  iproute2,
  networkmanager,
}:
kait2en.mkService {
  component = "drop";
  root = "apps/t2-drop";
  inherit (kait2en.modules) src;

  cargoHash = "sha256-zMTkBLXFiwo3L955nDF0F/Rx2YllhS09kVLWGNsIBHY=";

  # It sets up the AWDL interface through both.
  runtimeInputs."bin/t2drop" = [
    iproute2
    networkmanager
  ];

  passthru.port = 8770;

  meta = {
    description = "AirDrop daemon for Macs with an Apple T2 security chip";
    mainProgram = "t2drop";
  };
}
