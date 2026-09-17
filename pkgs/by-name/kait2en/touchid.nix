# Bridges the T2's Touch ID sensor to stock fprintd through libfprint's virtual
# storage device, so nothing in the fingerprint stack is patched: fprintd's own
# unit cannot reach a sensor that only answers over IPv6 on the CDC-NCM link.
# The finger is enrolled under macOS, the daemon only binds it to a Linux account.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/t2-touchid
{
  kait2en,
}:
kait2en.mkService {
  component = "touchid";

  cargoHash = "sha256-AEIkigG0aFT5UK3RuNef6jThU1ygv/jYRJnWS+ARWys=";

  # The daemon owns a bus name announcing its prompt state to the Touch Bar.
  postInstall = ''
    install -Dm444 -t $out/share/dbus-1/system.d \
      t2-services/t2-touchid/integration/dbus/org.kait2en.TouchId.conf
  '';

  meta = {
    description = "Apple T2 Touch ID bridge for fprintd";
    mainProgram = "t2-touchid";
  };
}
