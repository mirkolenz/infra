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
  version = "0.1.12-unstable-2026-11-02";

  src = kait2en.fetchSource {
    rev = "3206d9e4ea6cb49caba20f374954220555577fcc";
    hash = "sha256-Ggp0pPfmmwhXjzQDGivBupwffd45MwO/oilsHSXiUas=";
    root = "apps/t2-kbd-backlight";
  };

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
