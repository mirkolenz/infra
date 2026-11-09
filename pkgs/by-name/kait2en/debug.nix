# Shows bridgeOS processes like top and streams the T2's os_log, read-only
# through its Instruments service over the bridge link. `t2debug` is the same
# without a GUI.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-debug
{
  kait2en,
}:
kait2en.mkGtkApp {
  appId = "org.t2debug.gtk";
  version = "0.1.13-unstable-2026-11-08";

  src = kait2en.fetchSource {
    rev = "8de95468f08c6db37924bcb8f9adc12c769add71";
    hash = "sha256-4L10cF2LpoPqtARh6VaA8XuNZ7ZXq1zW3rhHd8TnD/Q=";
    root = "apps/t2-debug";
    bridgexpc = true;
    logos = [ "src/bin/t2-debug.rs" ];
  };

  cargoHash = "sha256-6zciw4vmiI2APy2f4z1XmYlSpXU/F38CT/0H8h2UvSE=";

  meta = {
    description = "Apple T2 bridgeOS process monitor and live log viewer";
    mainProgram = "t2-debug";
  };
}
