# Shows the fans, temperatures, power figures and battery state `t2smc`
# exposes. Its daemon lifts the charge limit for a full charge from time to
# time, like powerd on macOS, so the battery gauge can recalibrate.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-smc-control
{
  lib,
  kait2en,
  util-linux,
}:
kait2en.mkGtkApp {
  appId = "org.t2smccontrol.gtk";
  version = "0.1.13-unstable-2026-11-11";

  src = kait2en.fetchSource {
    rev = "9c6e22d0d5ece62351ccef78fe4bb710ab2dabaa";
    hash = "sha256-vMmJatQy7/rAsMB4+V92q+kEn4SRMvFOO6VWbFRiIz4=";
    root = "apps/t2-smc-control";
    logos = [ "src/main.rs" ];
  };

  cargoHash = "sha256-COrLe22eXodTxjUp0zj9dAY8kYHRtt3IY62MOQqhGhI=";

  # Run through pkexec, which does not search a PATH.
  postPatch = ''
    substituteInPlace $cargoRoot/src/main.rs \
      --replace-fail /usr/sbin/hwclock ${lib.getExe' util-linux "hwclock"}
  '';

  meta = {
    description = "Apple T2 SMC sensor and battery viewer";
    mainProgram = "t2-smc-control";
  };
}
