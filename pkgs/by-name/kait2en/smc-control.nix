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
  version = "0.1.12-unstable-2026-11-02";

  src = kait2en.fetchSource {
    rev = "3206d9e4ea6cb49caba20f374954220555577fcc";
    hash = "sha256-hIP5yG7RATrwOHwZUnlFPK1gP3vFnQ+goxM9895OCaU=";
    root = "apps/t2-smc-control";
    logos = true;
  };

  cargoHash = "sha256-eh1i9ud2m3FHog4+VRhWcL87z2QWVoWQZ829MKJSGVY=";

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
