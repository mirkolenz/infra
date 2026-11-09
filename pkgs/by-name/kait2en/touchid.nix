# Bridges the T2's Touch ID sensor to stock fprintd through libfprint's virtual
# storage device, so nothing in the fingerprint stack is patched: fprintd's own
# unit cannot reach a sensor that only answers over IPv6 on the CDC-NCM link.
# The finger is enrolled under macOS, the daemon only binds it to a Linux account.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/t2-touchid
{
  kait2en,
  fprintd,
  libinput,
  pkg-config,
  udev,
}:
kait2en.mkService {
  version = "0.1.13-unstable-2026-11-08";

  src = kait2en.fetchSource {
    rev = "8de95468f08c6db37924bcb8f9adc12c769add71";
    hash = "sha256-Yhs7waP7Nei8lJvYg9OF+C+w509xEb52v8sszAPAPZ8=";
    root = "t2-services/t2-touchid";
    bridgexpc = true;
  };

  cargoHash = "sha256-lU3F7BtkKm6SA3pFNEHC0SU/EvXvVCPvUuADMmBPHtw=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    libinput
    udev
  ];

  # Also the fprintd drop-in, and the D-Bus policy for the name announcing the
  # prompt to the Touch Bar.
  integration = true;
  bridge = true;

  # Binding an identity runs `fprintd-enroll`, which answers itself.
  runtimeInputs."bin/t2-touchid" = [ fprintd ];

  meta = {
    description = "Apple T2 Touch ID bridge for fprintd";
    mainProgram = "t2-touchid";
  };
}
