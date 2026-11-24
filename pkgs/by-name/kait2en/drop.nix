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
  version = "0.1.16-unstable-2026-11-23";

  src = kait2en.fetchSource {
    rev = "6915384500c59c7ac4842977a40b4269f122bdbc";
    hash = "sha256-r7xUIIpgFUrmWgh61zxa+Xv97QM4TeUtHQtvCjBT+4U=";
    root = "apps/t2-drop";
  };

  cargoHash = "sha256-lQeS2UkRIQj4c7yx9fApOc4GZfSi2c665hb4bywgMwo=";

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
