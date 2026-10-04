# Shows the fans, temperatures, power figures and battery state `t2smc`
# exposes.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-smc-control
{
  lib,
  kait2en,
  glib,
  util-linux,
}:
kait2en.mkGtkApp {
  component = "smc-control";
  appId = "org.t2smccontrol.gtk";

  cargoHash = "sha256-XPofREssRQHjnP+xLIxc/trbN31jX8jraIQk8BqP5gE=";

  # `build.rs` compiles the icon into a resource bundle.
  nativeBuildInputs = [ glib ];

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
