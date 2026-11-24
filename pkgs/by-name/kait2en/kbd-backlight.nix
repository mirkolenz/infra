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
  version = "0.1.16-unstable-2026-11-23";

  src = kait2en.fetchSource {
    rev = "6915384500c59c7ac4842977a40b4269f122bdbc";
    hash = "sha256-z6XhRWzuim6j8pxj86ZFQuMP3mRxB4MpBp7VjPyjwUg=";
    root = "apps/t2-kbd-backlight";
  };

  cargoHash = "sha256-yIKB/kJGIei08yHm3DroSYZ8+JIrz2lAlXNoprf3u7w=";

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
