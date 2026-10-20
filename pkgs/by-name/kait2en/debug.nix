# Shows bridgeOS processes like top and streams the T2's os_log, read-only
# through its Instruments service over the bridge link. `t2debug` is the same
# without a GUI.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-debug
{
  kait2en,
}:
kait2en.mkGtkApp {
  component = "debug";
  appId = "org.t2debug.gtk";
  inherit (kait2en.modules) src;

  cargoHash = "sha256-cRKCgUhf2dm+u+dUnRba/VM1WWe3zssqyAo62mHfDB8=";

  meta = {
    description = "Apple T2 bridgeOS process monitor and live log viewer";
    mainProgram = "t2-debug";
  };
}
