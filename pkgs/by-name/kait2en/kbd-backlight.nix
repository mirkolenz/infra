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
  version = "0.1.13-unstable-2026-11-11";

  src = kait2en.fetchSource {
    rev = "9c6e22d0d5ece62351ccef78fe4bb710ab2dabaa";
    hash = "sha256-Zt/yg82TjNFhTzX4l7ehplkWOK4seZlYj/WXT4KOAHQ=";
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
