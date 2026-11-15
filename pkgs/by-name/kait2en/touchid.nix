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
  version = "0.1.14-unstable-2026-11-15";

  src = kait2en.fetchSource {
    rev = "260a559597a7bd3b168a9a251a2248d97aadd957";
    hash = "sha256-SvcD0jT66orZOR0etBRwKddJ8aXYJf+v5kTHeNglTYk=";
    root = "t2-services/t2-touchid";
    bridgexpc = true;
  };

  cargoHash = "sha256-2pubP57S42DWKdgcNzYH7yT6I+9m/S+ozUjDUJBl/UI=";

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
