# True Tone, evening mode and automatic brightness on GNOME, through mutter
# and a shell extension that keeps the slider on the real brightness.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-truetone
{
  kait2en,
  glib,
}:
kait2en.mkGtkApp {
  version = "0.1.13-unstable-2026-11-08";

  src = kait2en.fetchSource {
    rev = "8de95468f08c6db37924bcb8f9adc12c769add71";
    hash = "sha256-er7jysXbG277T3Z+F5aY4t9CWiGV5x+8IPx2e9HXaJA=";
    root = "apps/t2-truetone";
  };

  cargoHash = "sha256-BYnw9rwrSBXBo76b7GDTCadWTkc3g/0z4IPSPJvOk7k=";

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
