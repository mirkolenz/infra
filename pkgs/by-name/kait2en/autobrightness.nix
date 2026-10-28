# Follows the ambient light sensor the way macOS does: changes fade in slowly,
# small ones are ignored, and a manual adjustment teaches the curve. It writes
# through mutter with GNOME's own automatics off, and its shell extension keeps
# the slider on the real brightness.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/t2-services/t2-autobrightness
{
  kait2en,
}:
kait2en.mkService {
  component = "autobrightness";
  inherit (kait2en.modules) src;

  cargoHash = "sha256-IQzkA2Zkp2Sy19GLZypYUTFwTDZlWHIJx3mMQaLse3E=";

  # A user unit and the shell extension.
  integration = true;

  meta = {
    description = "Automatic display brightness for Apple T2 MacBooks on GNOME";
    mainProgram = "t2-autobrightness";
  };
}
