# Fades the keyboard backlight out after a while without keyboard, trackpad or
# Touch Bar input and back in with the next, through UPower so GNOME's slider
# follows. It took this over from the Touch Bar daemon.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-kbd-backlight
{
  kait2en,
  libinput,
  pkg-config,
  udev,
}:
kait2en.mkService {
  component = "kbd-backlight";
  root = "apps/t2-kbd-backlight";
  inherit (kait2en.modules) src;

  cargoHash = "sha256-gBM8pN50szxul36GrGlKPtn0XqZ1ll/VsyTPS4+N0Kg=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    libinput
    udev
  ];

  meta = {
    description = "Keyboard backlight idle timeout for Apple T2 MacBooks";
    mainProgram = "t2-kbd-backlight";
  };
}
