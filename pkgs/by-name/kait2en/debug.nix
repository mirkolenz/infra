# Shows bridgeOS processes like top and streams the T2's os_log, read-only
# through its Instruments service over the bridge link. `t2debug` is the same
# without a GUI.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-debug
{
  kait2en,
}:
kait2en.mkGtkApp {
  appId = "org.t2debug.gtk";
  version = "0.1.16-unstable-2026-11-23";

  src = kait2en.fetchSource {
    rev = "6915384500c59c7ac4842977a40b4269f122bdbc";
    hash = "sha256-59hudU4vgr0kLTFL6rJQsX7XTuQC3eAzHqNMZa6OPrI=";
    root = "apps/t2-debug";
    bridgexpc = true;
    logos = [ "src/bin/t2-debug.rs" ];
  };

  cargoHash = "sha256-Ip6K5iMuXUSpa180UNdeYlAp96uY2MFzvbWpfAk/Vt4=";

  meta = {
    description = "Apple T2 bridgeOS process monitor and live log viewer";
    mainProgram = "t2-debug";
  };
}
