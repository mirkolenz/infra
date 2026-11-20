# Draws the Touch Bar itself instead of Apple's firmware row: dark until it is
# touched or Fn is pressed, with a media and an F-key row, the Touch ID prompt
# and haptic feedback. It replaces tiny-dfr, which its DRM setup derives from.
# https://github.com/kaiT2en/KaiT2en-Fedora/tree/main/apps/t2-touchbar
{
  lib,
  kait2en,
  adwaita-fonts,
  coreutils,
  libinput,
  pkg-config,
  systemd,
  udev,
  wireplumber,
}:
kait2en.mkService {
  version = "0.1.15-unstable-2026-11-19";

  src = kait2en.fetchSource {
    rev = "f457579e15bb028ad2eec8c6ca0f853118986ecf";
    hash = "sha256-PRswwT1WhYFXpZAkzPTvg5ZB5IlB4AAZx/6wXX9UV2A=";
    root = "apps/t2-touchbar";
  };

  cargoHash = "sha256-kAg9NTjw2RIV5lUPu43YyJ3bB8Rp+DNYCgOfUu9IH80=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    libinput
    udev
  ];

  # The daemon tries Fedora's font path first, and the udev rules hand the
  # backlight and the actuator to the device group through coreutils.
  postPatch = ''
    substituteInPlace $cargoRoot/src/renderer.rs \
      --replace-fail /usr/share/fonts/adwaita-sans-fonts/AdwaitaSans-Regular.ttf \
        ${adwaita-fonts}/share/fonts/Adwaita/AdwaitaSans-Regular.ttf
    substituteInPlace $cargoRoot/integration/udev/99-zz-kait2en-touchbar.rules \
      --replace-fail /bin/chgrp ${lib.getExe' coreutils "chgrp"} \
      --replace-fail /bin/chmod ${lib.getExe' coreutils "chmod"}
  '';

  # The attach unit only switches the panel while the daemon is enabled, which
  # here it is whenever the units are installed at all. The polkit rule lets
  # the user units start the root unit switching the panel for the session.
  # tiny-dfr's MIT notice goes next to the ones `installLicenses` ships.
  postInstall = ''
    install -Dm444 -t $out/lib/udev/rules.d \
      $cargoRoot/integration/udev/99-zz-kait2en-touchbar.rules
    install -Dm444 -t $out/share/polkit-1/rules.d \
      $cargoRoot/integration/polkit/50-kait2en-touchbar.rules
    cp -r $cargoRoot/integration/systemd $out/lib/systemd
    substituteInPlace $out/lib/systemd/system/*.service $out/lib/systemd/user/kait2en-touchbar.service \
      --replace-fail /usr/local/bin/kait2en-touchbar $out/bin/kait2en-touchbar
    substituteInPlace $out/lib/systemd/system/kait2en-touchbar-attach.service \
      --replace-fail 'ExecCondition=/usr/bin/systemctl --global is-enabled --quiet kait2en-touchbar.service' ""
    substituteInPlace $out/lib/systemd/system/kait2en-touchbar-attach.service \
      $out/lib/systemd/user/kait2en-touchbar-panel.service \
      --replace-fail /usr/bin/systemctl ${lib.getExe' systemd "systemctl"}
    install -Dm444 -t $out/share/licenses/kait2en-touchbar \
      $cargoRoot/THIRD-PARTY-NOTICES.md
  '';

  # It reads the volume levels through `wpctl`.
  runtimeInputs."bin/kait2en-touchbar" = [ wireplumber ];

  meta = {
    description = "Touch Bar daemon for Macs with an Apple T2 security chip";
    mainProgram = "kait2en-touchbar";
    license = with lib.licenses; [
      gpl3Plus
      mit
    ];
  };
}
