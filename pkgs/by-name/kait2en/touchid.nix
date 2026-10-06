# Bridges the T2's Touch ID sensor to stock fprintd through libfprint's virtual
# storage device, so nothing in the fingerprint stack is patched: fprintd's own
# unit cannot reach a sensor that only answers over IPv6 on the CDC-NCM link.
# The finger is enrolled under macOS, the daemon only binds it to a Linux account.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/t2-touchid
{
  kait2en,
  libinput,
  pkg-config,
  udev,
}:
kait2en.mkService {
  component = "touchid";
  inherit (kait2en.modules) src;

  cargoHash = "sha256-zkX6adYUZSZ5MzXcXaXvvV59M6tboLJnW1l4zNQRThk=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    libinput
    udev
  ];

  # Also the fprintd drop-in, and the D-Bus policy for the name announcing the
  # prompt to the Touch Bar.
  integration = true;

  meta = {
    description = "Apple T2 Touch ID bridge for fprintd";
    mainProgram = "t2-touchid";
  };
}
