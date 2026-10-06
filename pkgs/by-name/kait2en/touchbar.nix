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
  udev,
  udevCheckHook,
}:
kait2en.mkService {
  component = "touchbar";
  root = "apps/t2-touchbar";
  inherit (kait2en.modules) src;

  cargoHash = "sha256-7gteyON5LRLgFc5doIa3Bka93iQaYwt916ZsUPUjPdQ=";

  nativeBuildInputs = [
    pkg-config
    udevCheckHook
  ];
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
  # here it is whenever the units are installed at all. tiny-dfr's MIT notice
  # goes next to the ones `installLicenses` ships.
  postInstall = ''
    install -Dm444 -t $out/lib/udev/rules.d \
      $cargoRoot/integration/udev/99-zz-kait2en-touchbar.rules
    cp -r $cargoRoot/integration/systemd $out/lib/systemd
    substituteInPlace $out/lib/systemd/{system,user}/*.service \
      --replace-fail /usr/local/bin/kait2en-touchbar $out/bin/kait2en-touchbar
    substituteInPlace $out/lib/systemd/system/kait2en-touchbar-attach.service \
      --replace-fail 'ExecCondition=/usr/bin/systemctl --global is-enabled --quiet kait2en-touchbar.service' ""
    install -Dm444 -t $out/share/licenses/kait2en-touchbar \
      $cargoRoot/THIRD-PARTY-NOTICES.md
  '';

  doInstallCheck = true;

  meta = {
    description = "Touch Bar daemon for Macs with an Apple T2 security chip";
    mainProgram = "kait2en-touchbar";
    license = with lib.licenses; [
      gpl3Plus
      mit
    ];
  };
}
