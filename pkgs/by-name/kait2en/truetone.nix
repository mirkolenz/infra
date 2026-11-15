# True Tone, evening mode and automatic brightness on GNOME, through mutter
# and a shell extension that keeps the slider on the real brightness.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-truetone
{
  kait2en,
  glib,
}:
kait2en.mkGtkApp {
  version = "0.1.14-unstable-2026-11-15";

  src = kait2en.fetchSource {
    rev = "260a559597a7bd3b168a9a251a2248d97aadd957";
    hash = "sha256-5KiioU9dpYlYbmbL44WWpDaKIH/GOgsKOh0xu/q1zQU=";
    root = "apps/t2-truetone";
  };

  cargoHash = "sha256-U5hRhVAy05GRiOQ7jzo+9q3islUwET5M3W2X4u/8UGE=";

  appId = "org.t2truetone.gtk";
  userUnits = [ "t2-truetone.service" ];

  # It switches GNOME's own automatics and enables the extension through `gsettings`.
  runtimeInputs."bin/t2truetone" = [ glib ];

  postInstall = ''
    # The light sensor for the session daemon.
    install -Dm444 -t $out/lib/udev/rules.d $cargoRoot/udev/*.rules
    mkdir -p $out/share/gnome-shell/extensions
    cp -r $cargoRoot/integration/gnome-shell/* $out/share/gnome-shell/extensions
  '';

  meta = {
    description = "Ambient white point, evening mode and automatic brightness for Apple T2 MacBooks on GNOME";
    mainProgram = "t2-truetone";
  };
}
