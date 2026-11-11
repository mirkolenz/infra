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
  version = "0.1.13-unstable-2026-11-11";

  src = kait2en.fetchSource {
    rev = "9c6e22d0d5ece62351ccef78fe4bb710ab2dabaa";
    hash = "sha256-VfBFtncUZrE5ctWs8cIBV4pueWrT7P8hLQTsq8GCxuI=";
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
